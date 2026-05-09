# Trivium

> Where three roads cross: learning, work and virtual world.

Trivium is an open digital world built on [Luanti](https://www.luanti.org/) + [VoxeLibre](https://codeberg.org/VoxeLibre/VoxeLibre) that works as:

1. **Learning platform** — acquire knowels (verified capabilities), cultivate your Tree of Noesis and follow knowledge routes like in an RPG.
2. **3D virtual office** — work remotely with proximity chat and screen sharing within a persistent spatial environment.
3. **Explorable world** — an open voxel sandbox to explore, build and live.

## Architecture

Trivium is composed of three proprietary pieces and an infrastructure layer:

| Component | Technology | Responsibility |
|-----------|-----------|----------------|
| **Luanti Mod** | Lua on VoxeLibre | 3D world, proximity text chat, in-game Tree of Noesis, knowel system |
| **Companion App** | Flutter | Spatial voice chat, screen sharing, overlay, profile, subscription, org panel |
| **Backend** | Dart + PostgreSQL | Auth, tenants, progress, knowels, server provisioning |
| **Infrastructure** | GCP (GCE, Cloud Run, Cloud SQL) | Dedicated Luanti servers per organization, API on Cloud Run |

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│      Luanti + VoxeLibre     │     │      Companion App (Flutter) │
│         + Trivium Mod       │     │                              │
│                             │     │  • Voice chat (proximity)    │
│  • Open 3D world            │◄───►│  • Screen sharing            │
│  • Proximity text chat      │     │  • Status overlay            │
│  • In-game Tree of Noesis   │     │  • Profile and subscription  │
│  • Knowel system            │     │  • Organization panel        │
└──────────────┬──────────────┘     └──────────────┬───────────────┘
               │                                   │
               └──────────┬───────────────────────┘
                          │ HTTP/WS
                ┌─────────▼──────────┐
                │    Backend (Dart)   │
                │  auth · tenant     │
                │  progress · knowel │
                │  server (prov.)    │
                └─────────┬──────────┘
                          │
                ┌─────────▼──────────┐
                │   PostgreSQL (RLS) │
                └─────────┬──────────┘
                          │
                ┌─────────▼──────────┐
                │   Luanti Servers   │
                │   (public + orgs)  │
                └────────────────────┘
```

## Repo Structure

```
trivium/
├── code/             # Source code (mod + companion app)
├── docs/
│   ├── architecture.md  # System architecture
│   ├── spec/            # Technical specifications
│   │   ├── mod.md               # Trivium Mod (Lua)
│   │   ├── companion-app.md     # Companion App (Flutter)
│   │   ├── auth-svc.md          # Auth service
│   │   ├── tenant-svc.md        # Tenant + organizations service
│   │   ├── progress-svc.md      # Progress + tree service
│   │   ├── knowel-svc.md        # Knowel catalog service
│   │   ├── server-svc.md        # Server provisioning service
│   │   ├── database.md          # Database schema + RLS
│   │   ├── infrastructure.md    # GCE, LiveKit, Cloud Run, CI/CD
│   │   ├── world.md             # World design and capabilities
│   │   └── viridian.md          # Cosmology: Ensō, Viridian, Noesis
│   └── roadmap.md       # Project roadmap
└── README.md
```

## Documentation

### Architecture and Planning

- [System Architecture](docs/architecture.md) — components, backend, servers, pricing model
- [Roadmap](docs/roadmap.md) — release-by-release implementation (0.0 → 1.0)

### Technical Specs

- [Trivium Mod](docs/spec/mod.md) — proximity chat, position API, Tree of Noesis, knowel system (Lua)
- [Companion App](docs/spec/companion-app.md) — voice engine, screen sharing, mod bridge, UI (Flutter)
- [auth-svc](docs/spec/auth-svc.md) — registration, login, JWT, CLI admin tool
- [tenant-svc](docs/spec/tenant-svc.md) — organizations, members, roles, Stripe billing
- [progress-svc](docs/spec/progress-svc.md) — knowel progress, tree state, team dashboard
- [knowel-svc](docs/spec/knowel-svc.md) — knowel catalog, graph, quizzes, recommendations
- [server-svc](docs/spec/server-svc.md) — GCE provisioning, lifecycle, whitelist
- [Database](docs/spec/database.md) — PostgreSQL schema, RLS policies, migrations
- [Infrastructure](docs/spec/infrastructure.md) — GCE, LiveKit, Cloud Run, Cloud SQL, CI/CD

### Design Specs

- [World Spec](docs/spec/world.md) — world design, capabilities, two-component architecture
- [Cosmology](docs/spec/viridian.md) — Ensō, Viridian, Tree of Noesis, petals and knowels

## Status

In specification phase.