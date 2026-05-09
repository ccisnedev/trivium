# Roadmap — Trivium

> Release-by-release implementation. Each release delivers usable value.
> 
> Philosophy: **world first, knowledge second.** Release 0.0 proves the mod works. Releases 0.1–0.2 add spatial communication. Releases 0.3–0.6 build the platform and monetization. Releases 0.7–0.8 add the Knowel Adventure layer. 1.0 integrates everything.

---

## Roadmap Principles

- Each release is deployable and demonstrable.
- First the world works well: people enter, talk, share screens.
- Then monetization: accounts, Stripe, organizations.
- Finally the learning layer: Tree of Noesis, knowels, quizzes.
- Provisioning infrastructure is built just before opening orgs.

---

## Phase 1 — The Trivium World

### Release 0.0.x — Mod + Dev Server

**Objective:** Prove the mod works. A world where people can connect and talk by text when they are near each other. No companion app, no backend, no accounts.

| Deliverable | Detail |
|-------------|--------|
| Dev server | GCE instance with VoxeLibre + Trivium Mod. Manually provisioned via setup script. |
| Trivium Mod (Lua) | Proximity text chat (configurable radius). Validates the proximity mechanic before voice arrives in 0.1.x. |
| Access | Anyone with the server IP + Luanti + VoxeLibre installed can connect. No auth. |
| Documentation | README with instructions for connecting to the server. |

**Does not include:** voice, companion app, screen sharing, accounts, backend, payments.

**Success criterion:** Two people connect to the server, walk toward each other, and can only see text messages when they are within radius.

---

### Release 0.1.x — Spatial Voice + LiveKit

**Objective:** The minimum differentiator: a world where you can talk by voice with people near you. Without this, it is just VoxeLibre with a modified text chat.

> Luanti has no audio API or WebRTC. Spatial voice requires an external component that captures the microphone, manages WebRTC and reads the player's position. This is solved with a minimal voice client (Flutter) that connects to a LiveKit SFU server.

| Deliverable | Detail |
|-------------|--------|
| LiveKit server | LiveKit self-hosted on GCE (`e2-medium`). Single instance handling all voice. |
| Trivium Mod update | Server-side mod pushes player positions to the backend relay via HTTP. |
| Voice client (Flutter desktop) | Minimal app without complex UI: captures microphone, connects to LiveKit, receives positions from backend relay, adjusts volume by distance. Windows/macOS/Linux. **Testers install Luanti manually** (instructions in README). |
| Spatial voice chat | Voice with volume proportional to distance between players. Opus @ 48kHz via LiveKit SFU. |
| Documentation | README with instructions for installing mod + voice client and connecting to server. |

**Does not include:** screen sharing, accounts, backend, payments, elaborate UI.

**Success criterion:** Two people connect to the server, talk by voice, and the volume drops as they move apart. 15 testers can play simultaneously, using the minimal desktop app simply and organically in daily sessions without crashes.

---

### Release 0.2.x — Screen Sharing + Companion App

**Objective:** The voice client evolves into a full companion app with launcher capabilities, screen sharing, and zero-friction setup.

| Deliverable | Detail |
|-------------|--------|
| **Launcher / Installer** | The Companion App detects, installs (via winget/brew/apt), and manages Luanti + VoxeLibre + Trivium Mod. Adopts existing installations from 0.0–0.1 testers without reinstalling. Users launch Luanti from the Companion App's [▶ Play] button. |
| Companion App (Flutter desktop) | Full UI: home screen, setup wizard (first run), nearby player list, voice controls, screen panel, settings. |
| Screen sharing | Screen capture and transmission via LiveKit (WebRTC SFU) to nearby players. 1080p30+. |
| View another's screen | Panel in companion app to view the shared screen. |
| In-game indicator | The mod shows an indicator over the avatar of the player who is sharing. |
| Status overlay | Nearby players, mod notifications. |
| Auto-update | On each launch, checks Trivium Mod version and updates if newer. |

**Does not include:** accounts, backend, payments.

**Success criterion:** A new user downloads only the Companion App, which installs everything, and within 2 minutes they are in the world with voice and screen sharing working. Existing 0.1.x testers upgrade to 0.2.x and the app adopts their existing Luanti installation seamlessly.

---

## Phase 2 — Platform and Monetization

### Release 0.3.x — User Management + Web and Mobile App

**Objective:** Users create accounts and pay. Public registration requires Stripe payment (Premium plan). Free accounts only via CLI admin.

| Deliverable | Detail |
|-------------|--------|
| auth-svc | Registration and login with Firebase Auth. JWT issuance. |
| tenant-svc | Individual tenant creation on registration. |
| Database | PostgreSQL on Cloud SQL. Initial schema: users, tenants, tenant_members. |
| JWT middleware | Each Cloud Run service validates JWTs internally via `modular-api`. No separate API Gateway. |
| Login in companion app | Registration/login screen in the Flutter desktop app. |
| Companion App web | Flutter web: login, profile, account management from the browser. |
| Companion App mobile | Flutter mobile (Android/iOS): account management and profile. (Luanti Android exists, but voice/screen remains Desktop-optimized to avoid OS constraints). |
| Mod verification | The mod queries the backend for user account status. |
| CLI admin tool | `seed_user.dart` for creating free accounts (dev, QA, founder invites). |

**Success criterion:** A user registers from the web app, pays for Premium, logs in on the desktop companion app, and the mod recognizes their identity. Can manage their profile from mobile.

---

### Release 0.4.x — Stripe and Subscriptions

**Objective:** Complete Stripe integration. Registration flow requires payment.

| Deliverable | Detail |
|-------------|--------|
| Stripe Checkout | Registration flow: Firebase Auth → Stripe Checkout → Premium activated. |
| Individual premium plan | $5 USD/month or $50/year. |
| Subscription management | In companion app (desktop, web, mobile): view plan, change, cancel. |
| Plan verification in mod | The mod checks if the user is premium and enables future features. |
| Billing portal | Stripe Customer Portal for invoices and payment method. |
| Rate limiting | Registration endpoint rate-limited to prevent abuse. |

**Does not include:** premium in-game features yet (those come in 0.7). Premium gives full access to the world and prepares the payment infrastructure.

**Success criterion:** A user registers, pays $5/month via Stripe Checkout, and the mod knows they are premium.

---

### Release 0.5.x — Organizations

**Objective:** Premium users create organizations, invite members and pay per seat.

| Deliverable | Detail |
|-------------|--------|
| Organizational tenant | Organization CRUD in tenant-svc. A Premium user creates an org. |
| Member management | Email invitations, roles (owner, admin, member). |
| Per-seat billing | Stripe: monthly charge per active member count. |
| Organization panel | View in companion app: members, roles, subscription status. |
| Mod permissions | The mod knows which org the player belongs to. |

**Success criterion:** An admin creates an organization, invites 3 members, all 3 connect to the public server and the org recognizes them as a team.

---

### Release 0.6.x — Dedicated Server per Organization

**Objective:** Each organization with an active subscription gets its own Luanti server.

| Deliverable | Detail |
|-------------|--------|
| server-svc | Automatic provisioning of GCE instances with VoxeLibre + Trivium Mod. |
| Automatic configuration | Tenant member whitelist, pre-installed mod. |
| Lifecycle | Start, stop, restart servers from the companion app. |
| Monitoring | Server status (online/offline, connected players). |
| Direct connection | Members see their server in the companion app and connect from Luanti. |

**Success criterion:** An admin activates their org, within 5 minutes has a dedicated server, and their members connect directly.

---

## Phase 3 — Knowel Adventure

### Release 0.7.x — Tree of Noesis + Progress

**Objective:** Premium users plant their Tree of Noesis and accumulate progress. The learning layer begins here.

| Deliverable | Detail |
|-------------|--------|
| In-game Tree of Noesis | The premium player plants their tree (sakura). Grows visually with each knowel. |
| Skill tree | In-game interface when interacting with the tree: nodes, branches, unlocks. |
| progress-svc | Knowel progress persistence per user and tenant. |
| knowel-svc (basic) | Knowel CRUD. Initial catalog with example knowels. |
| Private knowels (org) | Knowels visible only within an organization's tenant. |
| Petals | Particles falling from the tree representing available knowels. |
| Team dashboard | Team progress view in the organization panel. |

**Success criterion:** A premium user plants their tree, completes a knowel, and the tree grows a branch. An org admin sees their team's progress.

---

### Release 0.8.x — Quizzes and Verification

**Objective:** Knowels are verified with quizzes. Progress is demonstrated capability, not consumed content.

| Deliverable | Detail |
|-------------|--------|
| In-game quizzes | Upon completing a knowel, the player answers verification questions. |
| Evaluation | knowel-svc evaluates answers and updates progress. |
| Progressive unlocking | Advanced knowels unlock upon completing prerequisites. |
| Relationship graph | knowel-svc manages prerequisites and derivations between knowels. |
| Recommendations | Next knowel suggestion based on graph and progress. |

**Success criterion:** A player completes a quiz, the knowel is marked as verified, and new knowels unlock in the skill tree.

---

## Release 1.x.x — Trivium Complete

**Objective:** First stable release. The world, platform and learning layer work as an integrated system.

| Deliverable | Detail |
|-------------|--------|
| Stability | Bug fixes, load testing, security hardening. |
| Onboarding | First-time experience: Ensō, dark coast, Viridian. |
| Complete documentation | User guide, org admin guide, mod development guide. |
| Landing page | Website with product information, pricing, registration. |
| Complete CI/CD | GitHub Actions: build, test, deploy for mod, app and backend. |

**Success criterion:** A person can discover Trivium, register, enter the world, learn something and share their tree. A company can create its organization, pay, have its server and train its team.

---

## Visual Summary

```
          ┌─── Phase 1: The World ─────────────────────────┐
          │                                                 │
0.0.x     │  Mod + dev server (text proximity only)         │
          │       │                                         │
0.1.x     │  Spatial voice + LiveKit                        │
          │       │                                         │
0.2.x     │  Screen sharing + companion app                 │
          │                                                 │
          └─────────────────────────────────────────────────┘
          │
          ┌─── Phase 2: Platform + Monetization ───────────┐
          │                                                 │
0.3.x     │  User management + web and mobile app           │
          │       │                                         │
0.4.x     │  Stripe + subscriptions                         │
          │       │                                         │
0.5.x     │  Organizations + seats                          │
          │       │                                         │
0.6.x     │  Dedicated server per org                       │
          │                                                 │
          └─────────────────────────────────────────────────┘
          │
          ┌─── Phase 3: Knowel Adventure ──────────────────┐
          │                                                 │
0.7.x     │  Tree of Noesis + progress                      │
          │       │                                         │
0.8.x     │  Quizzes + verification                         │
          │                                                 │
          └─────────────────────────────────────────────────┘
          │
1.x.x     First stable release
```

---

## After 1.0

Ideas for future releases (not yet specified):

- Remote desktop (mouse + keyboard control over shared screen, RustDesk-like, enables real pair programming)
- Knowel integration (import catalog, graph, content pipeline)
- Knowel marketplace
- Community learning routes
- Advanced gamification (streaks, achievements, domain rankings)
- Third-party mod plugin support
- Multi-region servers (latency)
- Public API for integrations