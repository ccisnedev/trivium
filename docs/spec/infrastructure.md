# Spec — Infrastructure

> Status: draft
> Version: 0.1.0
> Releases: 0.0.x (dev server), 0.1.x (LiveKit), 0.3.x (Cloud Run + Cloud SQL), 0.6.x (auto-provisioning)

---

## Summary

All Trivium infrastructure runs on Google Cloud Platform (GCP). This spec covers the GCE instances (Luanti servers + LiveKit), Cloud Run (backend services), Cloud SQL (PostgreSQL), networking, and the CI/CD pipeline.

---

## Infrastructure by Release

| Release | Infrastructure Added |
|---------|---------------------|
| 0.0.1 | 1 GCE instance: Luanti office test server provisioned with Terraform |
| 0.0.2–0.0.5 | Same Luanti server lifecycle, extended as the Trivium mod evolves |
| 0.1.x | 1 GCE instance: LiveKit server (manual) |
| 0.3.x | Cloud Run: auth-svc, tenant-svc. Cloud SQL: PostgreSQL. |
| 0.4.x | Stripe webhooks endpoint on Cloud Run. |
| 0.6.x | server-svc on Cloud Run. GCE API for auto-provisioning. |
| 0.7.x | Cloud Run: progress-svc, knowel-svc. |

### Release 0.0.1 Bootstrap Scope

The first deliverable is intentionally infrastructure-only so connectivity can be validated before any Trivium gameplay behavior is introduced.

Included in 0.0.1:

- Terraform-managed GCP resources for one office test server
- Static public IP and DNS mapping for the test hostname
- One Debian 12 Compute Engine VM running Luanti server + VoxeLibre
- Firewall rules for Luanti and restricted SSH access
- Startup or setup script that installs and starts the server reproducibly

Explicitly excluded from 0.0.1:

- Proximity voice chat
- LiveKit
- Companion app
- Backend services, databases, auth, payments
- Trivium gameplay logic beyond proving base world connectivity

Changing the machine size later (for example `e2-small` to `e2-medium`) is handled by changing the Terraform variable for `machine_type` and re-applying. This normally requires a VM restart, but the boot disk and static IP remain attached if declared as persistent resources.

---

## GCE Instances

### Dev/Public Luanti Server

| Parameter | 0.0.x–0.5.x (manual) | 0.6.x+ (server-svc managed) |
|-----------|----------------------|------------------------------|
| Machine type | `e2-medium` (2 vCPU, 4GB) | `e2-standard-2` (2 vCPU, 8GB) |
| OS | Debian 12 | Debian 12 |
| Disk | 20GB SSD | 20GB SSD |
| Ports | UDP 30000 | UDP 30000 |
| Setup | Terraform apply + startup/setup script | Automated via server-svc |
| Cost | ~$25/month | ~$50/month per org server |

For the office test world in 0.0.1, `e2-small` is an acceptable starting point if only a few internal users connect. Increase to `e2-medium` once CPU or memory headroom becomes tight.

### LiveKit Server

| Parameter | Value |
|-----------|-------|
| Machine type | `e2-medium` (2 vCPU, 4GB) |
| OS | Debian 12 |
| Software | LiveKit server binary (Go) |
| Ports | TCP 7880 (signaling), UDP 50000–60000 (media) |
| Config | Single YAML file |
| Cost | ~$25/month |
| Capacity | ~100 concurrent voice users |

### Setup Script (0.0.x–0.5.x)

Manual server provisioning via `code/infra/setup-server.sh`:

```bash
#!/bin/bash
set -euo pipefail

# --- Luanti Server ---
apt-get update && apt-get install -y luanti-server git

# Install VoxeLibre
git clone --depth 1 https://codeberg.org/VoxeLibre/VoxeLibre.git \
  /srv/luanti/games/VoxeLibre

# Install Trivium Mod
mkdir -p /srv/luanti/mods/trivium
# Copy mod files from local or GCS
cp -r /tmp/trivium-mod/* /srv/luanti/mods/trivium/

# Configure
cat > /srv/luanti/minetest.conf << EOF
name = Trivium
gameid = VoxeLibre
port = 30000
max_users = 30
creative_mode = false
enable_damage = true
default_privs = interact, shout
enable_bed_respawn = true
mcl_return_spawn = true
mob_difficulty = 3.0
server_name = Trivium Dev
EOF

# Start
systemctl enable luanti-server
systemctl start luanti-server
```

### LiveKit Setup Script

```bash
#!/bin/bash
set -euo pipefail

# Download LiveKit
LIVEKIT_VERSION="1.7.0"
wget -q "https://github.com/livekit/livekit/releases/download/v${LIVEKIT_VERSION}/livekit_${LIVEKIT_VERSION}_linux_amd64.tar.gz"
tar -xzf "livekit_${LIVEKIT_VERSION}_linux_amd64.tar.gz"
mv livekit /usr/local/bin/

# Configure
cat > /etc/livekit.yaml << EOF
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
keys:
  trivium-api: ${LIVEKIT_API_SECRET}
logging:
  level: info
EOF

# Systemd service
cat > /etc/systemd/system/livekit.service << EOF
[Unit]
Description=LiveKit Server
After=network.target

[Service]
ExecStart=/usr/local/bin/livekit --config /etc/livekit.yaml
Restart=always
User=livekit

[Install]
WantedBy=multi-user.target
EOF

useradd --system livekit
systemctl daemon-reload
systemctl enable livekit
systemctl start livekit
```

---

## Cloud Run Services

All backend Dart services run on Cloud Run:

| Service | Min instances | Max instances | Memory | CPU |
|---------|-------------|--------------|--------|-----|
| auth-svc | 0 | 3 | 256MB | 1 |
| tenant-svc | 0 | 3 | 256MB | 1 |
| progress-svc | 0 | 3 | 256MB | 1 |
| knowel-svc | 0 | 3 | 512MB | 1 |
| server-svc | 0 | 2 | 256MB | 1 |

- Cold start is acceptable (Dart compiles to native, starts in <1s).
- Min instances = 0 saves costs in early stages.
- All services connect to Cloud SQL via Cloud SQL Proxy (unix socket).
- All services authenticate via JWT (auth-svc issues, others verify).

---

## Cloud SQL

| Parameter | Dev | Production |
|-----------|-----|-----------|
| Tier | `db-f1-micro` | `db-custom-2-4096` |
| Engine | PostgreSQL 15 | PostgreSQL 15 |
| Storage | 10GB SSD | 10GB SSD (auto-increase) |
| Region | `us-central1` | `us-central1` |
| HA | No | Yes |
| Backups | Manual | Daily, 7-day retention |
| Connections | Cloud SQL Proxy | Private IP + Proxy |
| Cost | ~$10/month | ~$50/month |

---

## Networking

### VPC

- Single VPC: `trivium-vpc`
- Subnet: `trivium-subnet` in `us-central1` (`10.0.0.0/24`)
- Cloud Run services connect via Serverless VPC Connector
- Cloud SQL on private IP within VPC
- GCE instances in same VPC

### Firewall Rules

| Rule | Source | Target | Ports | Protocol |
|------|--------|--------|-------|----------|
| `allow-luanti` | `0.0.0.0/0` | tag: `trivium-server` | 30000 | UDP |
| `allow-livekit-signal` | `0.0.0.0/0` | tag: `trivium-livekit` | 7880 | TCP |
| `allow-livekit-media` | `0.0.0.0/0` | tag: `trivium-livekit` | 50000–60000 | UDP |
| `allow-ssh` | admin IPs | tag: `trivium-server`, `trivium-livekit` | 22 | TCP |
| `deny-all-ingress` | `0.0.0.0/0` | all | all | all |

### DNS

- `play.trivium.world` → Public Luanti server IP
- `livekit.trivium.world` → LiveKit server IP
- `api.trivium.world` → Direct mapped to Cloud Run services (e.g. `api.trivium.world/auth`, `api.trivium.world/tenant`). Does not use a heavy API Gateway.
- `app.trivium.world` → Companion App web (Flutter web on Firebase Hosting)

---

## Observability & Error Handling

- **Structured Logging:** Implemented in backend services using the `modular-api` package (JSON logs straight to Cloud Logging).
- **Metrics:** `modular-api` exposes Prometheus endpoints which are scraped or pushed to Cloud Monitoring.
- **Alerting:** Uptime checks on `/auth/health`, high latency alarms.

---

## Disaster Recovery & Backups

- **Cloud SQL:** Daily automated backups.
- **RPO (Recovery Point Objective):** 24 hours.
- **RTO (Recovery Time Objective):** 4 hours max.
- **Export:** Weekly dump to a multi-region Google Cloud Storage (GCS) bucket.

## CI/CD — GitHub Actions

### Pipelines

| Pipeline | Trigger | Actions |
|----------|---------|---------|
| `mod-ci` | Push to `code/mod/` | Lint Lua, run mod tests |
| `app-ci` | Push to `code/app/` | `flutter analyze`, `flutter test`, build desktop/web/mobile |
| `backend-ci` | Push to `code/backend/` | `dart analyze`, `dart test` per service |
| `deploy-backend` | Tag `backend-v*` | Build Docker images, push to Artifact Registry, deploy to Cloud Run |
| `deploy-app-web` | Tag `app-v*` | Build Flutter web, deploy to Firebase Hosting |
| `release-app-desktop` | Tag `app-v*` | Build Windows/macOS/Linux installers |
| `release-mod` | Tag `mod-v*` | Package mod, upload to GCS |

### Deployment Flow

```
push to main → CI (lint, test, analyze)
tag vX.Y.Z   → build → push image → deploy to Cloud Run
```

---

## Cost Estimate (Early Stage)

| Resource | Monthly Cost |
|----------|-------------|
| GCE: Luanti dev server (`e2-medium`) | ~$25 |
| GCE: LiveKit server (`e2-medium`) | ~$25 |
| Cloud SQL (`db-f1-micro`) | ~$10 |
| Cloud Run (5 services, low traffic) | ~$5 |
| Networking (egress, DNS) | ~$5 |
| **Total** | **~$70/month** |

This scales as org servers are added (~$50/month per org server).

---

## Open Questions

- Whether LiveKit and the Luanti dev server should share one GCE instance or run separately.
- Domain registrar and SSL certificate strategy (Let's Encrypt vs Google-managed).
- Whether to use Terraform, Pulumi or manual gcloud scripts for infrastructure-as-code.
- Log aggregation strategy (Cloud Logging, or export to external).
- Alerting: Cloud Monitoring alerts for server health, high CPU, payment failures.
- Whether to use Artifact Registry or Container Registry for Docker images.
