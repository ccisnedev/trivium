# Luanti Release Process

## Purpose

This document describes the validated process for shipping Luanti to the office server without recompiling Luanti on every VM rebuild.

The current production path is:

- Build a versioned Luanti server bundle outside the VM.
- Upload that bundle to the private GCS artifacts bucket.
- Point Terraform at the versioned `gs://...` object.
- Rebuild the office VM in a controlled way while preserving the world disk.

## Current Architecture

The office server now consumes Luanti through a private artifact pipeline.

- Private artifacts bucket: `cacsi-virtual-office-artifacts`
- Bundle consumer: the office VM
- VM service account: `office-server-vm@cacsi-virtual-office.iam.gserviceaccount.com`
- Bucket permission: `roles/storage.objectViewer`
- Download mechanism: authenticated HTTP request using the Compute Engine metadata server token
- World persistence path: `/srv/trivium-office-data/world`
- Live bundle pattern: `gs://cacsi-virtual-office-artifacts/luanti/<version>/luanti-server-<version>-linux-amd64.tar.gz`

## Recommended Build Environment

For routine releases, build the bundle in Linux CI.

That is the preferred long-term process because it is:

- reproducible
- easier to audit
- independent from a developer workstation
- easier to version and publish consistently

### Acceptable Temporary Option

WSL is acceptable for manual or emergency releases.

If CI is not ready yet, you can build from:

- WSL on Windows
- a native Linux workstation
- a disposable Linux VM

Do not make the live office VM the normal build environment for future releases. The VM should consume artifacts, not produce them.

## Bundle Contents

The bundle is a tar.gz archive containing a server-capable Luanti tree.

Important details:

- The startup script accepts either `gs://...` or a generic URL.
- The startup script removes any bundled `games/VoxeLibre` tree before cloning VoxeLibre again. This avoids ownership and Git safety issues.
- VoxeLibre remains installed during bootstrap, separate from the Luanti engine bundle.

## Manual Build Steps

### 1. Build the bundle in Linux or WSL

Run the helper script from the repository root or any convenient working directory:

```bash
bash code/infra/office/scripts/build-luanti-server-bundle.sh 5.16.1 /tmp/luanti-server-5.16.1-linux-amd64.tar.gz
```

The script:

- clones the requested Luanti tag
- builds the server-only bundle
- strips the Git metadata
- writes a tar.gz archive

### 2. Compute the SHA256 checksum

Example:

```bash
sha256sum /tmp/luanti-server-5.16.1-linux-amd64.tar.gz
```

Store the checksum next to the bundle.

### 3. Upload the bundle to GCS

Example:

```bash
gcloud storage cp /tmp/luanti-server-5.16.1-linux-amd64.tar.gz \
  gs://cacsi-virtual-office-artifacts/luanti/5.16.1/luanti-server-5.16.1-linux-amd64.tar.gz

printf '%s' '<sha256>' | gcloud storage cp - \
  gs://cacsi-virtual-office-artifacts/luanti/5.16.1/luanti-server-5.16.1-linux-amd64.tar.gz.sha256
```

Use immutable, versioned paths.

Do not overwrite an existing object for the same version.

## Terraform Rollout

### 1. Bootstrap prerequisites

The bootstrap stack creates the private artifacts bucket.

If that bucket does not exist yet, apply bootstrap first:

```powershell
terraform -chdir=code/infra/bootstrap apply -auto-approve `
  -var "project_id=cacsi-virtual-office" `
  -var "billing_account=<billing-account-id>"
```

### 2. Apply the office stack with the bundle URL

Example:

```powershell
terraform -chdir=code/infra/office apply -auto-approve `
  -var "project_id=cacsi-virtual-office" `
  -var 'admin_cidrs=["190.119.218.98/32"]' `
  -var "luanti_bundle_url=gs://cacsi-virtual-office-artifacts/luanti/5.16.1/luanti-server-5.16.1-linux-amd64.tar.gz"
```

What Terraform does during this rollout:

- creates or reuses the dedicated VM service account
- grants that service account read access to the artifacts bucket
- replaces the office VM when the startup bootstrap changes
- reattaches the persistent world disk to the replacement VM
- redeploys the worldmods after the VM becomes reachable

## Validation Checklist

After the rollout, validate all of the following.

### Terraform validation

```powershell
terraform -chdir=code/infra/bootstrap validate
terraform -chdir=code/infra/bootstrap test
terraform -chdir=code/infra/office validate
terraform -chdir=code/infra/office test
```

### Runtime validation

```powershell
gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a --command "sudo systemctl is-active trivium-office"

gcloud compute ssh ccisnedev@office-server --project=cacsi-virtual-office --zone=us-central1-a --command "sudo ls -ld /srv/trivium-office-data/world /srv/trivium-office-data/world/worldmods"
```

Expected outcomes:

- `trivium-office` is `active`
- the world still lives under `/srv/trivium-office-data/world`
- `trivium` and `trivium_access` are still present in `worldmods`

## Rollback

If a new Luanti bundle fails validation:

1. Keep the world disk untouched.
2. Point `luanti_bundle_url` back to the last known good bundle.
3. Re-run the office Terraform apply.
4. Validate the service and world state again.

Because the world data is stored on a dedicated persistent disk, rolling back the engine bundle does not require rebuilding the world state.

## Known Operational Notes

- Windows + `gcloud` + PuTTY/Plink can show host key prompts after a VM replacement. This is expected when the instance key changes.
- The mutable worldmod deploy now waits for TCP port 22 before trying to copy files.
- The attached world disk is explicitly recreated when the office VM is replaced, so the persistent world reappears inside the new instance.
- The current flow has been validated against a private GCS bundle, not only against a public URL.

## Recommended Next Step

The manual release path is now documented and works.

The next improvement should be a Linux CI workflow that:

- builds the Luanti bundle from a tag
- computes and stores the checksum
- uploads both files to the private artifacts bucket
- optionally opens a change with the new `luanti_bundle_url`