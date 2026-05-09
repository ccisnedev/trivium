# Architecture — Trivium

> Version: 1.2.0

---

## Summary

Trivium is an independent system composed of three proprietary components and an infrastructure layer:

1. **Luanti Mod** — 3D world, proximity chat (text fallback), in-game Tree of Noesis, in-game knowels (Lua)
2. **Companion App** — launcher, spatial voice chat, screen sharing, overlay, account and subscription management (Flutter)
3. **Backend** — API, auth, users, tenants, subscriptions, progress, knowels, server provisioning (Dart + PostgreSQL)
4. **Infrastructure** — automatic provisioning of Luanti servers for organizations (GCP)

Knowel is a separate project with its own repo. Trivium can integrate with Knowel to consume its content catalog, graph and quizzes, but Trivium does not depend on Knowel to function. Knowels within Trivium can come from Knowel or be managed directly.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 USER                                        │
│                                                                             │
│   ┌─────────────────────┐             ┌──────────────────────────┐          │
│   │  Luanti + VoxeLibre │             │  Companion App (Flutter) │          │
│   │  + Trivium Mod      │             │                          │          │
│   │                     │             │  • Voice chat            │          │
│   │  • 3D World         │             │  • Screen sharing        │          │
│   │  • Proximity chat   │             │  • Overlay               │          │
│   │  • In-game tree     │             │  • Login / profile       │          │
│   │  • In-game knowels  │             │  • Subscription          │          │
│   └────────┬────────────┘             └────────────┬─────────────┘          │
│            │                                       │                        │
└────────────┼───────────────────────────────────────┼────────────────────────┘
             │ HTTP (Push positions)                 │ HTTP/WS
             │                                       │ WebSocket (Relay sync)
     ┌───────▼───────────────────────────────────────▼───────┐
     │           Trivium Backend (Cloud Run)                 │
     │      (Independent services with built-in JWT Auth)    │
     └───┬──────┬──────────┬──────────┬───────────┬──────────┘
         │      │          │          │           │
    ┌────▼──┐ ┌─▼───────┐ ┌▼────────┐ ┌▼────────┐ ┌▼─────────┐
    │auth   │ │tenant   │ │progress │ │knowel   │ │server    │
    │-svc   │ │-svc     │ │-svc     │ │-svc     │ │-svc      │
    │(Dart) │ │(Dart)   │ │(Dart)   │ │(Dart)   │ │(Dart)    │
    └───┬───┘ └────┬────┘ └───┬─────┘ └───┬─────┘ └────┬─────┘
        │          │          │           │            │
    ┌───▼──────────▼──────────▼───────────▼────────────▼─────┐
    │              PostgreSQL (multi-tenant, RLS)            │
    └─────────────────────────┬──────────────────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │   Luanti Server    │
                    │   (1 per org or    │
                    │    public server)  │
                    └────────────────────┘
```

---

## Components

### 1. Luanti Mod (Lua)

Lua code extending VoxeLibre. Runs on both the client and server side of Luanti.

| Function | Detail |
|----------|--------|
| Open 3D world | Provided by VoxeLibre. Not built from scratch. |
| Proximity text chat | Text fallback for when voice is unavailable. Messages visible only within a configurable radius. Secondary to spatial voice. |
| In-game Tree of Noesis | The player plants their tree (sakura). Grows with knowels. Skill tree interface on interaction. |
| In-game knowel system | Knowel list, progress tracking, progressive unlocking. |
| Backend Sync | Server-side mod pushes player state to the backend relay over HTTP to broadcast to companion apps. |
| Server-side mod | Validates progress, manages shared state, and handles communication with backend. |

**Repo path:** `code/mod/`

### 2. Companion App (Flutter)

Native cross-platform app that serves as the **single entry point** for the Trivium experience. From 0.2.x it acts as a launcher that manages the installation and lifecycle of Luanti, VoxeLibre and the Trivium Mod.

| Function | Detail |
|----------|--------|
| **Launcher (0.2.x+)** | Detects/installs Luanti (winget/brew/apt), VoxeLibre, Trivium Mod. Adopts existing installations. Launches Luanti from a [▶ Play] button. Auto-updates mod. |
| Spatial voice chat | Audio with volume proportional to distance. LiveKit (WebRTC SFU). Desktop-optimized. |
| Screen sharing | Captures and transmits screen to nearby players or group. LiveKit. Desktop-optimized (publishing). |
| Status overlay | Nearby players, zone knowels, notifications. |
| Login and profile | Authentication, account management. (Mobile, Web, Desktop) |
| Subscription and payment | Individual or organizational plan management. Stripe. |
| Organization panel | Invite members, view team dashboard, manage seats. |
| Sync | Connects via WebSocket to receive live game state, and reads/writes progress via REST. |

**Platforms:** Windows, macOS, Linux (desktop) · Android, iOS (mobile) · Web

**Repo path:** `code/app/`

### 3. Backend (Dart + PostgreSQL)

Five independent Dart microservices deployed on Cloud Run.

#### auth-svc

| Responsibility | Detail |
|---------------|--------|
| Registration and login | Firebase Auth as identity provider. |
| Token issuance | JWT for authenticating against other services. |
| Account linking | A user can belong to multiple tenants. |

#### tenant-svc

| Responsibility | Detail |
|---------------|--------|
| Tenant CRUD | Create, read, update organizations. |
| Member management | Invitations, roles (owner, admin, member), deactivation. |
| Subscriptions | Plan management, seats, billing via Stripe. |
| Server provisioning | When activating an organizational tenant, requests server-svc to create a dedicated Luanti server. |

#### progress-svc

| Responsibility | Detail |
|---------------|--------|
| Knowel progress | Record completed knowels, in-progress, quiz scores. |
| Tree state | Persist the Tree of Noesis state for each user. |
| Skill tree | Unlocked branches, specializations, masteries. |
| Sync | Receives updates from the mod and companion app. |

#### knowel-svc

| Responsibility | Detail |
|---------------|--------|
| Knowel catalog | CRUD of knowels available in Trivium. |
| Private knowels | Knowels visible only within a tenant (internal training). |
| Relationship graph | Prerequisites, derivations, suggested paths. |
| Quizzes | Generation and evaluation of verification questions. |
| Knowel integration (optional) | Can sync knowels from the Knowel repo/API if configured. |

#### server-svc

| Responsibility | Detail |
|---------------|--------|
| Provisioning | Create and destroy Luanti server instances for organizations. |
| Lifecycle | Start, stop, restart servers. |
| Configuration | Apply Trivium mod, configure tenant member whitelist, adjust parameters. |
| Monitoring | Server status (online/offline), connected players, resource usage. |
| Public server | Manage the Trivium public server for individual and free users. |

### 4. Infrastructure — Server Provisioning

When an organization pays for its subscription (minimum 1 seat), a dedicated Luanti server is provisioned.

#### Provisioning Flow

```
1. Admin creates organization in companion app
2. Selects plan and pays (Stripe)
3. tenant-svc registers the tenant and sends request to server-svc
4. server-svc:
   a. Creates a Compute Engine instance
   b. Installs VoxeLibre + Trivium Mod
   c. Configures whitelist with tenant members
   d. Starts the server
   e. Returns IP/port to tenant-svc
5. tenant-svc saves the server address in the DB
6. Tenant members see their server in the companion app
7. They connect directly from Luanti
```

#### Server Model

| Type | For whom | Provisioning | Connection Logic |
|------|----------|-------------|-------------------|
| **Public server** | Premium individual users | Always active. Managed by Trivium. | Default lobby/hub for individuals. Users who join orgs graduate to their org server. |
| **Organization server** | Tenant members | Provisioned on subscription activation. Dedicated. | Isolated sandbox for the org's team, trees, and private knowels. |

### Inter-Service Communication

Since we aren't using a heavy API Gateway:
- **Client-to-Service**: App apps connect directly to the exposed Cloud Run service endpoints. JWTs are validated inside each service via shared middleware (`modular-api`).
- **Service-to-Service**: HTTP REST. A service calls another service attaching an internal JWT signed with `aud: <target_service>`.

---

## Database Schema

```sql
-- Users
users (
  id              uuid PRIMARY KEY,
  firebase_uid    text UNIQUE NOT NULL,
  luanti_username text UNIQUE NOT NULL,
  display_name    text,
  email           text,
  deleted_at      timestamptz,
  created_at      timestamptz DEFAULT now()
);

-- Tenants
tenants (
  id             uuid PRIMARY KEY,
  name           text NOT NULL,
  type           text NOT NULL CHECK (type IN ('individual', 'organization')),
  owner_user_id  uuid REFERENCES users(id),
  billing_email  text,
  plan           text NOT NULL CHECK (plan IN ('premium', 'organization')),
  max_seats      integer,
  stripe_customer_id  text,
  stripe_subscription_id text,
  server_id      uuid REFERENCES servers(id),
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

-- Tenant members
tenant_members (
  id          uuid PRIMARY KEY,
  tenant_id   uuid REFERENCES tenants(id),
  user_id     uuid REFERENCES users(id),
  role        text NOT NULL DEFAULT 'member',
  joined_at   timestamptz DEFAULT now(),
  removed_at  timestamptz
);

-- Luanti servers
servers (
  id          uuid PRIMARY KEY,
  tenant_id   uuid REFERENCES tenants(id),
  type        text NOT NULL CHECK (type IN ('public', 'organization')),
  host        text,
  port        integer DEFAULT 30000,
  status      text NOT NULL DEFAULT 'provisioning',
  gce_instance_name text,
  gce_zone    text,
  created_at  timestamptz DEFAULT now(),
  stopped_at  timestamptz
);

-- Knowels
knowels (
  id          uuid PRIMARY KEY,
  tenant_id   uuid,  -- NULL = public, NOT NULL = tenant-private
  slug        text UNIQUE NOT NULL,
  title       text NOT NULL,
  domain      text,
  content     jsonb,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- Knowel relationships
knowel_links (
  id          uuid PRIMARY KEY,
  source_id   uuid REFERENCES knowels(id),
  target_id   uuid REFERENCES knowels(id),
  link_type   text NOT NULL DEFAULT 'prerequisite'
);

-- User progress
user_progress (
  id          uuid PRIMARY KEY,
  user_id     uuid REFERENCES users(id),
  tenant_id   uuid REFERENCES tenants(id),
  knowel_id   uuid REFERENCES knowels(id),
  status      text NOT NULL DEFAULT 'available',
  quiz_score  integer,
  completed_at timestamptz,
  UNIQUE (user_id, tenant_id, knowel_id)
);

-- Personal tree
user_tree_branches (
  id            uuid PRIMARY KEY,
  user_id       uuid REFERENCES users(id),
  tenant_id     uuid REFERENCES tenants(id),
  domain        text NOT NULL,
  mastery_level integer NOT NULL DEFAULT 0
);

user_tree_unlocks (
  id          uuid PRIMARY KEY,
  user_id     uuid REFERENCES users(id),
  tenant_id   uuid REFERENCES tenants(id),
  knowel_id   uuid REFERENCES knowels(id),
  unlocked_at timestamptz DEFAULT now()
);

-- Audit
audit_log (
  id              uuid PRIMARY KEY,
  actor_user_id   uuid,
  tenant_id       uuid,
  action          text,
  target_type     text,
  target_id       uuid
);
```

All tables with `tenant_id` enforce Row-Level Security. Queries always filter by the authenticated user's tenant.

---

## Pricing Model

Public registration requires payment. There is no free plan available for public sign-up.

| Plan | Price | Includes | Registration |
|------|-------|----------|--------------|
| **Free** | $0 | Mod + public world + voice + text chat + screen sharing. No progress, no tree. | CLI admin only. Dev, QA, founder invites. Not available publicly. |
| **Premium** | $5 USD/month · $50/year | All features: Tree of Noesis, progress, skill tree, quizzes, recommendations, profile. Plays on public server. | Public registration (requires Stripe payment). |
| **Organization** | $/user/month (TBD) | Everything Premium + dedicated Luanti server + private knowels + team dashboard + member management. | A Premium user creates an org and purchases seats. |

### Feature Matrix

*(Note: Free accounts exist solely via CLI for testers/dev and mirror Premium functionality without payment. They are not publicly available.)*

| Feature | Premium | Org |
|---------|---------|-----|
| Mod + open world | ✅ | ✅ |
| Proximity text chat (fallback) | ✅ | ✅ |
| Voice chat (companion app, desktop) | ✅ | ✅ |
| Screen sharing (companion app, desktop) | ✅ | ✅ |
| Tree of Noesis | ✅ | ✅ |
| Persistent progress | ✅ | ✅ |
| Skill tree | ✅ | ✅ |
| Quizzes | ✅ | ✅ |
| Dedicated server | ❌ | ✅ |
| Private knowels | ❌ | ✅ |
| Team dashboard | ❌ | ✅ |

### Dev Seed Process

Free accounts are created exclusively via CLI admin tool, never through public registration.

```bash
dart run bin/seed_user.dart --email user@example.com --plan free --role admin
```

The CLI creates the user in Firebase Auth and inserts the record in PostgreSQL with the specified plan. This is used for development, QA and founder invites only.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| 3D World | Luanti + VoxeLibre |
| Mod | Lua (Luanti API) |
| Companion App | Flutter (Win, macOS, Linux, Android, iOS, Web) |
| Backend API | Dart (shelf / dart_frog), Cloud Run |
| Database | PostgreSQL (Cloud SQL), multi-tenant with RLS |
| Auth | Firebase Authentication |
| Payments | Stripe |
| Voice/Screen | LiveKit self-hosted on GCE (WebRTC SFU, Apache 2.0) |
| Luanti server hosting | GCE (Compute Engine) |
| General infra | GCP |
| CI/CD | GitHub Actions |

---

## Relationship with Knowel

Knowel is an independent project with its own repo. Integration is optional:

| Integration | Detail |
|-------------|--------|
| Import knowels | knowel-svc can sync knowels from the Knowel API. |
| Shared graph | Knowel relationships can be fed from the Knowel graph. |
| Content pipeline | Videos and materials generated by Knowel can be referenced in Trivium. |
| Independence | Trivium works without Knowel. Knowels can be created directly in knowel-svc. |

---

## Communication Scope

Trivium provides exactly two real-time communication primitives:

| Capability | Detail | Quality Target |
|-----------|--------|----------------|
| **Spatial voice** | Audio with volume proportional to distance between players. | High quality, low latency (<200ms). Opus @ 48kHz. |
| **Screen sharing** | Transmit screen to nearby players for code review, demos, tutoring. | Excellent. 1080p30 minimum. |

Trivium is **not** Discord, Gather, Slack or Zoom. It does not implement: chat channels, message threads, bots, streaming to audiences, video grids, or asynchronous messaging.

Future consideration (post-1.0): **remote desktop** — mouse and keyboard control over a shared screen (RustDesk-like), enabling real pair programming and full remote collaboration.

---

## Decisions

- Trivium is an independent system with its own Dart + PostgreSQL backend.
- Knowel is a separate project; integration is optional.
- Multi-tenancy: shared database, shared schema, `tenant_id` filtering, RLS.
- Organizations with at least 1 paid seat get a dedicated Luanti server provisioned automatically.
- The public server is for Premium individual users.
- **Paid only**: public registration requires payment (Premium plan). Free accounts exist only for dev/QA via CLI admin.
- Payments via Stripe (Stripe Checkout, not custom forms).
- Luanti server hosting on GCE.
- **LiveKit self-hosted on GCE** for voice and screen sharing. SFU architecture (not P2P mesh). Open-source (Apache 2.0). Can migrate to LiveKit Cloud if needed.
- The companion app is cross-platform Flutter (Voice/Screen Desktop-optimized).
- Mod ↔ companion app sync delegates to the Cloud Backend (WebSocket Relay) instead of doing insecure client-side IPC.
- Both connect to the backend services directly (Cloud Run, JWT checked on edge). No API Gateway.
- **Dev server**: manually provisioned GCE instance with setup script. Automatic provisioning (server-svc) comes in 0.6.
- Communication scope: spatial voice + screen sharing only. No Discord/Slack/Gather feature set.

---

## Open Questions

- Exact organizational plan pricing per user/month.
- Default GCE instance size for organization servers.
- Whether an org server auto-shuts down when no players are connected (cost savings) or stays always active.
- Billing: Stripe direct, Play Store/App Store for mobile, or both.
- Whether the mod can work without backend connection (offline mode with later sync).
- Player limit per public server.
- Whether LiveKit runs on the same GCE instance as the Luanti server or on a separate one.