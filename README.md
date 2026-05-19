# Trivium

> Where three roads cross: learning, work, and virtual world.

Trivium is a persistent online world built on Luanti + VoxeLibre.

The project combines three product directions in a single system:

1. A 3D virtual office for remote collaboration.
2. A learning platform centered on knowels and the Tree of Noesis.
3. An explorable voxel world where those systems live together.

## Current State

- `0.0.1` completed: remote office test world on GCP.
- `0.0.2` completed: Trivium mod scaffold deployed safely on the server.
- `0.0.3` completed: proximity text chat implemented and acceptance-tested.
- Next stage: `0.1.x` spatial voice with LiveKit.

## Main Components

| Component | Technology | Role |
|-----------|------------|------|
| Luanti Mod | Lua | In-world behavior: proximity text chat, later tree, knowels, and backend sync |
| Companion App | Flutter | Spatial voice, screen sharing, launcher, overlay, account flows |
| Backend | Dart + PostgreSQL | Auth, tenants, progress, knowels, and server lifecycle |
| Infrastructure | GCP | Luanti servers, LiveKit, Cloud Run, Cloud SQL, networking |

## Repository Layout

| Path | Purpose |
|------|---------|
| `code/mod/` | Luanti mods (`trivium`, `trivium_access`) |
| `code/app/` | Companion app source |
| `code/api/` | Backend services |
| `code/infra/` | Infrastructure and deployment assets |
| `docs/` | Architecture, specs, roadmap, operations |

## Start Here

- [docs/roadmap.md](docs/roadmap.md): release plan from `0.0.x` to `1.x`.
- [docs/architecture.md](docs/architecture.md): high-level system architecture.
- [docs/spec/index.md](docs/spec/index.md): component and infrastructure specs.
- [docs/logbook.md](docs/logbook.md): implementation history and field notes.

## Operations

- [docs/luanti-release-process.md](docs/luanti-release-process.md): Luanti bundle build and rollout process.
- [docs/proximity-chat-test-manual.md](docs/proximity-chat-test-manual.md): acceptance test manual for release `0.0.3`.

## Status

The office world is live, the Trivium mod is running on the remote server, and proximity text chat is validated in production-like usage. The next active track is the design and delivery of spatial voice for `0.1.x`.