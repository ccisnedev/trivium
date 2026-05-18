# Logbook

## 2026-05-17 — v0.0.1 Office World Bootstrap

### Iteration Goal

Bring up the first Trivium office world on GCP with Terraform, Luanti, and VoxeLibre, reachable from a local client through `office.cacsi.dev`.

This iteration corresponds to release `0.0.1` defined in [docs/roadmap.md](docs/roadmap.md).

### Scope

- `0.0.1` covers infrastructure and base connectivity only.
- It does not include the Trivium mod.
- It does not include spatial voice.
- It does not include backend, auth, billing, or the companion app.
- The acceptance test for this phase is joining the world from a local Luanti client.

---

## What Was Done

### 1. The `0.0.x` phase was split into smaller releases

`0.0.x` was split to separate infrastructure risk from gameplay risk:

- `0.0.1`: office world bootstrap on GCP
- `0.0.2`: safe Trivium mod deployment
- `0.0.3`: proximity text chat

This structure is reflected in [docs/roadmap.md](docs/roadmap.md).

### 2. Terraform was adopted with TDD

Terraform was chosen from day one so the infrastructure would be reproducible and scalable.

Two stacks were implemented:

- [code/infra/bootstrap/main.tf](code/infra/bootstrap/main.tf): GCP project, base APIs, and state bucket
- [code/infra/office/main.tf](code/infra/office/main.tf): static IP, firewall rules, and office VM

Tests were written before the implementation was completed:

- [code/infra/bootstrap/bootstrap.tftest.hcl](code/infra/bootstrap/bootstrap.tftest.hcl)
- [code/infra/office/office.tftest.hcl](code/infra/office/office.tftest.hcl)

Validation executed:

- `terraform test`
- `terraform validate`

---

## GCP Resources Created

### Project

- Name and ID: `cacsi-virtual-office`

### Enabled APIs

- `compute.googleapis.com`
- `dns.googleapis.com`
- `storage.googleapis.com`

### Terraform Remote State

- Bucket: `cacsi-virtual-office-tfstate`

### Office Server

- Instance: `office-server`
- Zone: `us-central1-a`
- Initial machine type: `e2-small`
- Static IP: `34.55.29.155`
- Game port: UDP `30000`

### DNS

- Domain: `office.cacsi.dev`
- Managed manually in Namecheap through an A record
- Current value: `34.55.29.155`

---

## Confirmed State

### Infrastructure

- The GCP project exists.
- The static IP exists.
- The UDP `30000` firewall rule exists.
- The restricted SSH firewall rule exists.
- The VM exists and is in `RUNNING`.
- `office.cacsi.dev` resolves to `34.55.29.155`.

### Game Server

- The startup script completed successfully.
- The `trivium-office` systemd service is `active`.
- The final running process is `luantiserver`.
- The server is listening on `0.0.0.0:30000`.
- The world is now stored under `/srv/trivium-office-data/world`.
- The loaded game is `VoxeLibre`.
- The active world profile is `survival`: no creative mode, damage enabled, respawn enabled, and `mob_difficulty = 3.0`.
- The `trivium_access` worldmod is loaded and persists state in `mod_storage`.
- World-level whitelist protection is active.
- The bootstrap admin account is `ccisnedev`.
- `Javier` remains allowed, but is no longer the bootstrap admin account.

Confirmed startup log line:

- `Server for gameid="VoxeLibre" listening on 0.0.0.0:30000.`

### Local Client

- This workstation already has Luanti installed through `winget`.
- The detected local version is `5.15.2`.
- A real connection from the local PC to `office.cacsi.dev:30000` was validated.
- Reconnection after restarting `trivium-office` was validated without losing the world.
- Non-blocking observation: during rain, the ambient rain audio may fail to resume after reconnecting even when rain remains visible. This appears to be an internal VoxeLibre `mcl_weather` synchronization issue and did not block the `0.0.1` closeout.

---

## Issues Found and Corrections

### Issue 1. Debian 12 did not provide installable server packages

Initial failed attempts:

- `apt-get install -y luanti-server`
- `apt-get install -y minetestserver`

Result:

- Both failed with `Unable to locate package`.

Correction applied:

- Luanti `5.16.1` was initially compiled from the official source on the VM.
- The client build was disabled.
- Unit tests and documentation were disabled to reduce build time.

Implemented in [code/infra/office/scripts/startup.sh](code/infra/office/scripts/startup.sh).

### Issue 2. The initial VoxeLibre URL was not suitable for non-interactive bootstrap

Initial failed attempt:

- `https://codeberg.org/VoxeLibre/VoxeLibre.git`

Symptom:

- The clone redirected to login or failed non-interactively.

Correction applied:

- It was replaced with an anonymously cloneable public repository:
- `https://codeberg.org/tacotexmex/voxelibre.git`

### Issue 3. GCE SSH failed because of the automatically derived username

Symptom:

- `gcloud compute ssh office-server ...` attempted to use a numeric Windows-derived local user and failed.

Lesson:

- On this workstation, GCE access should always use an explicit username.

Correct form:

- `gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a ...`

### Issue 4. SSH host key changed after VM replacement

Terraform replaced the instance several times while the startup bootstrap was being adjusted.

Observed effect:

- the SSH host key changed
- Plink showed a fingerprint warning

This was expected because the VM had been destroyed and recreated.

### Issue 4b. The world lived on the boot disk and was lost when the VM was replaced

Symptom:

- after replacing the instance, the server still worked
- but the world looked brand new, accounts had to be recreated, and prior progress was gone

Cause:

- the `office` world lived on the VM boot disk
- that boot disk had `autoDelete = true`
- there was no separate disk for world data
- there were no snapshots to recover the prior state

Correction applied:

- a dedicated persistent disk was added for world data
- the world moved from `/opt/luanti` to `/srv/trivium-office-data/world`
- the mutable deployment now mounts that disk, migrates the existing world, and rewrites the service to use the persistent path
- future VM replacements must not delete the world while the data disk remains attached

### Issue 5. The first world profile left players in creative and invulnerable mode

Symptom:

- When joining the world, the player appeared in creative mode or with behavior equivalent to `god mode`.

Cause:

- The bootstrap had left `creative_mode = true`.
- The bootstrap had left `enable_damage = false`.

Correction applied:

- The server profile was changed to `survival` with `creative_mode = false`.
- Damage was enabled with `enable_damage = true`.
- `enable_bed_respawn = true` and `mcl_return_spawn = true` were set explicitly so normal respawn is always available.
- `mob_difficulty = 3.0` was set as an explicit high-difficulty profile.
- Existing player accounts in the world were migrated to remove `fly`, enforce `gamemode = survival`, and clean up the internal `mcl_meshhand` state that still carried creative toolcaps.

Technical note:

- VoxeLibre does not expose a closed `easy/normal/hard` scale. It uses the numeric multiplier `mob_difficulty`.
- In this iteration, `3.0` was fixed as an explicit, reproducible high-difficulty setting.
- In VoxeLibre, changing `minetest.conf` does not always fix existing players. Gamemode and some toolcaps can remain persisted under `worlds/<world>/players/*` and require manual migration.

---

## Relevant Technical Decisions

### 1. Terraform remains the source of truth

This infrastructure should not be provisioned manually again. Terraform is the source of truth.

### 2. Office DNS is managed outside GCP for now

There is no Cloud DNS zone for `cacsi.dev` in this project. The record is managed manually in Namecheap.

### 3. Source compilation was a compatibility decision, not the end state

Luanti was originally compiled during bootstrap because of two concrete constraints:

- upstream did not publish official Linux binaries for release `5.16.1`
- Debian 12 only provided `minetest-server 5.6.1`, which was too old for a modern pinned server version

The recommended long-term approach is not compiling Luanti on every VM rebuild, but reusing a pinned prebuilt artifact.

### 3b. The correct Luanti distribution path is now in place

The recommended path to avoid compiling Luanti on every VM rebuild has now been applied:

- private artifacts bucket: `cacsi-virtual-office-artifacts`
- versioned Luanti bundle in GCS, consumed by the VM through a `gs://...` path
- dedicated VM service account with minimal `roles/storage.objectViewer` permission on that bucket
- authenticated startup download using the GCE metadata server

Result validated in real infrastructure:

- the `office` VM was rebuilt using a private bundle instead of compiling Luanti from source
- `trivium-office` returned to `active`
- the world and worldmods remained under `/srv/trivium-office-data/world`

Operational lesson:

- future bundles can be generated manually from Linux or WSL as a temporary path
- the correct long-term path is building and publishing the bundle from Linux CI, not from the local PC as the primary process

### 4. The `e2-small` machine is enough to start, not to scale

The machine type is parameterized. If more headroom is needed:

- change `machine_type` in Terraform
- reapply

That will normally restart or replace the VM, but the static IP remains preserved as long as it stays declared separately.

### 5. `code/mod/trivium_access` is the only source of truth

The first implementation left an embedded copy of the worldmod inside the startup script. That is no longer the correct state.

Current correct state:

- The mod source lives in [code/mod/trivium_access/init.lua](code/mod/trivium_access/init.lua).
- The base startup only prepares the VM, installs Luanti, installs VoxeLibre, and points the world to persistent storage outside the boot disk.
- Terraform deploys worldmods separately through [code/infra/office/scripts/deploy-worldmods.ps1](code/infra/office/scripts/deploy-worldmods.ps1).
- Changing files in [code/mod/trivium_access/init.lua](code/mod/trivium_access/init.lua) or [code/mod/trivium/init.lua](code/mod/trivium/init.lua) no longer implies recreating the VM.
- Replacing the VM must not reset the world while the persistent disk remains intact.

---

## Useful Commands

### Check the world service state

```powershell
gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a --command "sudo systemctl is-active trivium-office; sudo journalctl -u trivium-office -n 80 --no-pager"
```

### Check the startup script state

```powershell
gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a --command "sudo systemctl is-active google-startup-scripts; sudo journalctl -u google-startup-scripts.service -n 80 --no-pager"
```

### Check the VM serial output

```powershell
gcloud compute instances get-serial-port-output office-server --project=cacsi-virtual-office --zone=us-central1-a --port=1
```

### Check DNS resolution

```powershell
nslookup office.cacsi.dev
```

### Administer players from inside the game

These operations no longer require editing `auth.txt` manually. They are handled from an account with the `trivium_admin` privilege.

Current bootstrap account with that privilege:

- `ccisnedev`

```text
/trivium_whitelist
/trivium_whitelist on
/trivium_whitelist off
/trivium_allow <player>
/trivium_allow <player> survival
/trivium_allow <player> creative
/trivium_admin <player> on
/trivium_admin <player> off
/trivium_deny <player>
/trivium_user <player>
```

Useful examples:

- Allow a new architect to join in creative mode: `/trivium_allow Architect creative`
- Also grant whitelist administration: `/trivium_admin Architect on`
- Remove access from a user: `/trivium_deny Guest`

Behavior:

- If the whitelist is `on`, an unauthorized name cannot register or join.
- `creative` is applied per user when entering the world.
- `survival` is re-applied on the next join if the user is not marked as creative.
- `trivium_deny` kicks the player if they are online.

### Apply the office infrastructure

```powershell
terraform apply -auto-approve -var "project_id=cacsi-virtual-office" -var 'admin_cidrs=["190.119.218.98/32"]'
```

Note: `admin_cidrs` reflects the public IP used during this iteration and may change.

Operational note: after the `v0.0.2` refactor, a `terraform apply` that only changes worldmods should no longer propose destroying `google_compute_instance.office`; it should only rerun the mutable mod deployment resource.

---

## Important Files Created or Modified

- [docs/roadmap.md](docs/roadmap.md)
- [code/infra/bootstrap/versions.tf](code/infra/bootstrap/versions.tf)
- [code/infra/bootstrap/variables.tf](code/infra/bootstrap/variables.tf)
- [code/infra/bootstrap/main.tf](code/infra/bootstrap/main.tf)
- [code/infra/bootstrap/outputs.tf](code/infra/bootstrap/outputs.tf)
- [code/infra/bootstrap/bootstrap.tftest.hcl](code/infra/bootstrap/bootstrap.tftest.hcl)
- [code/infra/office/versions.tf](code/infra/office/versions.tf)
- [code/infra/office/variables.tf](code/infra/office/variables.tf)
- [code/infra/office/main.tf](code/infra/office/main.tf)
- [code/infra/office/outputs.tf](code/infra/office/outputs.tf)
- [code/infra/office/office.tftest.hcl](code/infra/office/office.tftest.hcl)
- [code/infra/office/scripts/startup.sh](code/infra/office/scripts/startup.sh)
- [code/infra/office/scripts/deploy-worldmods.ps1](code/infra/office/scripts/deploy-worldmods.ps1)
- [docs/luanti-release-process.md](docs/luanti-release-process.md)

---

## 2026-05-17 — v0.0.2 Mod Scaffold and Mutable Deployment

### Applied Architecture Change

The immutable VM bootstrap was separated from mutable worldmod deployment:

- `startup.sh` no longer embeds the contents of `trivium_access` or `trivium`.
- The VM keeps its static IP `34.55.29.155` and does not need to be recreated for mod iterations.
- Terraform now tracks a fingerprint of the mod contents and reruns only the mutable deployment when they change.

### Validation Executed

- `terraform test`: OK
- `terraform validate`: OK
- `terraform plan`: no VM recreation and no pending changes at the end
- Remote verification: `trivium-office` in `active`
- Remote verification: `trivium_access` and `trivium` worldmods present under `/srv/trivium-office-data/world/worldmods`

### Functional Signal Observed in Logs

Confirmed in the service journal:

- `[trivium] Trivium mod scaffold active (v0.0.2). Proximity chat is not enabled yet. Radii configured: whisper=8 talk=32 shout=128.`

---

## Current Exact State

`v0.0.1` is closed: remote infrastructure, real local client connectivity, and reconnection after restart have already been validated.

`v0.0.2` already has the main mod scaffold loaded on the server, with worldmod deployment separated from the VM lifecycle.
