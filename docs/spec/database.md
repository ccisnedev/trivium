# Spec — Database

> Status: draft
> Version: 0.1.0
> Releases: 0.3.x (users, tenants), 0.5.x (full org schema), 0.6.x (servers), 0.7.x (knowels, progress, trees)

---

## Summary

Single PostgreSQL database (Cloud SQL) with a shared-schema multi-tenant design. All tenant-scoped tables enforce Row-Level Security (RLS) to ensure data isolation.

---

## Multi-Tenancy Design

| Aspect | Decision |
|--------|----------|
| Strategy | Shared database, shared schema, `tenant_id` column |
| Isolation | Row-Level Security (RLS) policies on every tenant-scoped table |
| Context | JWT contains `tenant_ids` → backend sets `app.current_tenant_id` per request |
| Cross-tenant | Users can belong to multiple tenants; queries always filter by one active tenant |

### RLS Policy Pattern

```sql
-- Enable RLS
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;

-- Policy: users see only their own tenant's data
CREATE POLICY tenant_isolation ON user_progress
  USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- Service role bypasses RLS for admin operations
CREATE POLICY service_bypass ON user_progress
  FOR ALL TO service_role
  USING (true);
```

Each backend service sets the tenant context before executing queries:

```sql
SET LOCAL app.current_tenant_id = '<uuid>';
```

---

## Schema

### Core Tables (0.3.x)

```sql
CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid    text UNIQUE NOT NULL,
  luanti_username text UNIQUE NOT NULL, -- Identidad in-game
  display_name    text,
  email           text,
  deleted_at      timestamptz,          -- Soft delete
  created_at      timestamptz DEFAULT now()
);

CREATE TABLE tenants (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL,
  type           text NOT NULL CHECK (type IN ('individual', 'organization')),
  owner_user_id  uuid REFERENCES users(id),
  billing_email  text,
  plan           text NOT NULL CHECK (plan IN ('premium', 'organization')),
  max_seats      integer,
  stripe_customer_id      text,
  stripe_subscription_id  text,
  server_id      uuid,  -- FK added after servers table exists
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

CREATE TABLE tenant_members (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid REFERENCES tenants(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
  role        text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at   timestamptz DEFAULT now(),
  removed_at  timestamptz,
  UNIQUE (tenant_id, user_id)
);
```

### Server Tables (0.6.x)

```sql
CREATE TABLE servers (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid REFERENCES tenants(id),
  type                text NOT NULL CHECK (type IN ('public', 'organization')),
  host                text,
  port                integer DEFAULT 30000,
  status              text NOT NULL DEFAULT 'provisioning'
                      CHECK (status IN ('provisioning', 'online', 'stopped', 'destroying', 'destroyed', 'error')),
  gce_instance_name   text,
  gce_zone            text,
  created_at          timestamptz DEFAULT now(),
  stopped_at          timestamptz
);

-- Add FK from tenants to servers
ALTER TABLE tenants ADD CONSTRAINT fk_server
  FOREIGN KEY (server_id) REFERENCES servers(id);
```

### Knowel Tables (0.7.x)

```sql
CREATE TABLE knowels (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid REFERENCES tenants(id),  -- NULL = public
  slug        text UNIQUE NOT NULL,
  title       text NOT NULL,
  domain      text,
  content     jsonb,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

CREATE TABLE knowel_links (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id   uuid REFERENCES knowels(id) ON DELETE CASCADE,
  target_id   uuid REFERENCES knowels(id) ON DELETE CASCADE,
  link_type   text NOT NULL DEFAULT 'prerequisite'
              CHECK (link_type IN ('prerequisite', 'derivation', 'related')),
  UNIQUE (source_id, target_id, link_type)
);
```

### Progress Tables (0.7.x)

```sql
CREATE TABLE user_progress (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
  tenant_id   uuid REFERENCES tenants(id) ON DELETE CASCADE,
  knowel_id   uuid REFERENCES knowels(id) ON DELETE CASCADE,
  status      text NOT NULL DEFAULT 'available'
              CHECK (status IN ('available', 'in-progress', 'completed')),
  quiz_score  integer CHECK (quiz_score >= 0 AND quiz_score <= 100),
  completed_at timestamptz,
  updated_at  timestamptz DEFAULT now(),
  UNIQUE (user_id, tenant_id, knowel_id)
);

CREATE TABLE user_tree_branches (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES users(id) ON DELETE CASCADE,
  tenant_id     uuid REFERENCES tenants(id) ON DELETE CASCADE,
  domain        text NOT NULL,
  mastery_level integer NOT NULL DEFAULT 0,
  updated_at    timestamptz DEFAULT now(),
  UNIQUE (user_id, tenant_id, domain)
);

CREATE TABLE user_tree_unlocks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
  tenant_id   uuid REFERENCES tenants(id) ON DELETE CASCADE,
  knowel_id   uuid REFERENCES knowels(id) ON DELETE CASCADE,
  unlocked_at timestamptz DEFAULT now(),
  UNIQUE (user_id, tenant_id, knowel_id)
);
```

### Audit Log (0.3.x)

```sql
CREATE TABLE audit_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id   uuid REFERENCES users(id) ON DELETE SET NULL,
  tenant_id       uuid REFERENCES tenants(id) ON DELETE CASCADE,
  action          text NOT NULL,
  target_type     text NOT NULL,
  target_id       uuid,
  metadata        jsonb DEFAULT '{}',
  created_at      timestamptz DEFAULT now()
);
```

---

## Indexes

```sql
-- Users
CREATE INDEX idx_users_firebase ON users(firebase_uid);
CREATE INDEX idx_users_email ON users(email);

-- Tenant members
CREATE INDEX idx_members_tenant ON tenant_members(tenant_id) WHERE removed_at IS NULL;
CREATE INDEX idx_members_user ON tenant_members(user_id) WHERE removed_at IS NULL;

-- Servers
CREATE INDEX idx_servers_tenant ON servers(tenant_id);
CREATE INDEX idx_servers_status ON servers(status);

-- Knowels
CREATE INDEX idx_knowels_tenant ON knowels(tenant_id);
CREATE INDEX idx_knowels_domain ON knowels(domain);
CREATE INDEX idx_knowels_slug ON knowels(slug);

-- Knowel links
CREATE INDEX idx_links_source ON knowel_links(source_id);
CREATE INDEX idx_links_target ON knowel_links(target_id);

-- Progress
CREATE INDEX idx_progress_user_tenant ON user_progress(user_id, tenant_id);
CREATE INDEX idx_progress_knowel ON user_progress(knowel_id);
CREATE INDEX idx_progress_status ON user_progress(status);

-- Trees
CREATE INDEX idx_tree_branches_user_tenant ON user_tree_branches(user_id, tenant_id);
CREATE INDEX idx_tree_unlocks_user_tenant ON user_tree_unlocks(user_id, tenant_id);

-- Audit
CREATE INDEX idx_audit_tenant_action ON audit_log(tenant_id, action);
CREATE INDEX idx_audit_actor ON audit_log(actor_user_id);
```

---

## Migration Strategy

Migrations are versioned SQL files applied in order:

```
code/backend/migrations/
├── 001_create_users.sql
├── 002_create_tenants.sql
├── 003_create_tenant_members.sql
├── 004_create_servers.sql
├── 005_create_knowels.sql
├── 006_create_knowel_links.sql
├── 007_create_user_progress.sql
├── 008_create_user_trees.sql
├── 009_add_rls_policies.sql
└── 010_add_indexes.sql
```

Migrations are applied via a CLI tool:

```bash
dart run bin/migrate.dart --up
dart run bin/migrate.dart --status
dart run bin/migrate.dart --rollback 008
```

---

## Cloud SQL Configuration

| Parameter | Value |
|-----------|-------|
| Engine | PostgreSQL 15+ |
| Instance | `db-f1-micro` (dev) → `db-custom-2-4096` (prod) |
| Storage | 10GB SSD (auto-increase) |
| Region | `us-central1` |
| Connections | Private IP within VPC + Cloud SQL Proxy for Cloud Run |
| Backups | Daily automated, 7-day retention |

---

## Open Questions

- Whether `knowels.content` (jsonb) should store full learning material or just metadata.
- Whether to use database-level enums (`CREATE TYPE`) or text CHECK constraints for status fields.
- Soft delete strategy: `removed_at` column vs separate archive tables.
