# Spec — server-svc

> Status: draft
> Version: 0.1.0
> Release: 0.6.x

---

## Summary

Luanti server provisioning and lifecycle management service. Automatically creates, configures and manages GCE instances running VoxeLibre + Trivium Mod for organizations with active subscriptions.

Also manages the Trivium public server for individual Premium users.

**Runtime:** Dart on Cloud Run
**Repo path:** `code/backend/server-svc/`

---

## Responsibilities

- Provision dedicated Luanti server instances on GCE
- Install and configure VoxeLibre + Trivium Mod on instances
- Manage tenant member whitelists
- Server lifecycle: start, stop, restart, destroy
- Monitor server status and connected players
- Manage the public Trivium server

---

## API Endpoints

### POST /servers

Provision a new server for an organization. Called by tenant-svc when an org subscription is activated.

**Headers:** `Authorization: Bearer <jwt>` (service-to-service)

**Request:**
```json
{
  "tenant_id": "uuid",
  "type": "organization",
  "members": ["player1", "player2", "player3"]
}
```

**Response:** `202 Accepted`
```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "status": "provisioning",
  "estimated_ready": "2026-07-01T12:05:00Z"
}
```

**Provisioning steps:**
1. Create GCE instance (machine type, zone, boot disk)
2. Run startup script: install Luanti, VoxeLibre, Trivium Mod
3. Configure `minetest.conf` with tenant-specific settings
4. Configure whitelist with tenant member names
5. Start Luanti server process
6. Health check: wait for port 30000 to respond
7. Update status to `online`, return host/port to tenant-svc

### GET /servers/:id

Get server status and details.

**Response:** `200 OK`
```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "type": "organization",
  "host": "34.56.78.90",
  "port": 30000,
  "status": "online",
  "gce_instance_name": "trivium-org-abc123",
  "gce_zone": "us-central1-a",
  "players_online": 3,
  "created_at": "2026-07-01T12:00:00Z"
}
```

### PUT /servers/:id/start

Start a stopped server.

### PUT /servers/:id/stop

Stop a running server (preserves instance and world data).

### PUT /servers/:id/restart

Restart the server process.

### DELETE /servers/:id

Destroy the server. Deletes the GCE instance. World data is lost unless backed up.

### GET /servers/:id/players

Get currently connected players.

**Response:** `200 OK`
```json
{
  "players": [
    { "name": "carlos", "connected_since": "2026-07-01T14:00:00Z" },
    { "name": "alice", "connected_since": "2026-07-01T14:05:00Z" }
  ]
}
```

### PUT /servers/:id/whitelist

Update the server whitelist with current tenant members.

**Request:**
```json
{
  "members": ["carlos", "alice", "bob"]
}
```

---

## Server Status States

```
provisioning → online → stopped → online
                  ↓
              destroying → destroyed
```

| Status | Meaning |
|--------|---------|
| `provisioning` | GCE instance being created and configured |
| `online` | Server running, accepting connections |
| `stopped` | Server process stopped, instance preserved |
| `destroying` | Instance being deleted |
| `destroyed` | Instance deleted |
| `error` | Provisioning or runtime error |

---

## GCE Configuration

### Instance Defaults

| Parameter | Default | Notes |
|-----------|---------|-------|
| Machine type | `e2-standard-2` | 2 vCPU, 8GB RAM. Sufficient for ~20 concurrent players. |
| Boot disk | 20GB SSD | Luanti + VoxeLibre + world data |
| OS | Debian 12 | Stable, lightweight |
| Zone | `us-central1-a` | Configurable per tenant (future: multi-region) |
| Network tag | `trivium-server` | For firewall rules |

### Firewall Rules

| Rule | Port | Protocol | Source |
|------|------|----------|--------|
| Luanti game | 30000 | UDP | `0.0.0.0/0` |
| LiveKit (if co-located) | 7880, 50000-60000 | TCP/UDP | `0.0.0.0/0` |
| SSH (admin) | 22 | TCP | Restricted IP range |

### Startup Script

The startup script automates what `setup-server.sh` does manually in 0.0.x–0.5.x:

```bash
#!/bin/bash
apt-get update && apt-get install -y luanti
# Install VoxeLibre
git clone https://codeberg.org/VoxeLibre/VoxeLibre.git /srv/luanti/games/VoxeLibre
# Install Trivium Mod
gsutil cp gs://trivium-releases/mod/latest.tar.gz /tmp/
tar -xzf /tmp/latest.tar.gz -C /srv/luanti/mods/trivium
# Configure
cp /tmp/minetest.conf /srv/luanti/minetest.conf
# Start
systemctl enable luanti-server
systemctl start luanti-server
```

---

## Public Server

The public server is a special case:

| Aspect | Public Server | Org Server |
|--------|--------------|-----------|
| Tenant | No tenant (or a system tenant) | Organization tenant |
| Whitelist | None (open to all Premium users) | Tenant members only |
| Provisioning | Manual in 0.0.x–0.5.x, managed by server-svc in 0.6.x+ | Automatic |
| Lifecycle | Always on | Start/stop by org admin |

---

## Dependencies

| Dependency | Purpose |
|-----------|---------|
| GCE API (Compute Engine) | Create/manage VM instances |
| GCS (Cloud Storage) | Store mod releases and server configs |
| PostgreSQL | Store server records |
| tenant-svc | Receives provisioning triggers, provides member lists |
| auth-svc | Service-to-service authentication |

---

## Security

- All endpoints require a valid JWT (validated via `modular-api` middleware).
- Server lifecycle operations (start, stop, destroy) require `owner` or `admin` role on the tenant.
- GCE API credentials use a dedicated service account with minimum required permissions.
- Server provisioning validates the tenant has an active subscription before creating resources.

---

## Observability

Integrated via `modular-api` package: structured logging, request metrics, and distributed tracing.

---

## Open Questions

- Whether org servers should auto-stop when no players are connected for N hours (cost savings).
- Backup strategy for world data (snapshots, GCS export).
- Whether to support custom minetest.conf settings per organization.
- Maximum number of concurrent players per org server (and whether to allow upgrading instance size).
- Whether LiveKit should run on the same instance as the Luanti server or on a separate dedicated instance.
- Multi-region support: how to let orgs choose their server region.
