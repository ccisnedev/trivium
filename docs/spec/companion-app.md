# Spec — Companion App

> Status: draft
> Version: 0.2.0
> Releases: 0.1.x (voice client), 0.2.x (launcher + screen sharing), 0.3.x (auth + web + mobile), 0.4.x (subscriptions), 0.5.x (org panel)

---

## Summary

The Companion App is a Flutter application that serves as the **single entry point** for the Trivium experience. Starting from 0.2.x it acts as a launcher that manages the installation and lifecycle of Luanti, VoxeLibre and the Trivium Mod — eliminating all setup friction for the user.

It also provides spatial voice chat, screen sharing, status overlay, authentication, subscription management and organization administration.

It starts as a minimal voice client in 0.1.x (testers install Luanti manually), becomes the launcher + full companion app in 0.2.x, and grows incrementally from there.

**Repo path:** `code/app/`

---

## Evolution by Release

| Release | Form | Capabilities |
|---------|------|-------------|
| 0.1.x | Voice client (desktop only) | Mic capture, LiveKit connection, spatial audio. Minimal UI. Testers install Luanti manually. |
| 0.2.x | **Launcher** + Companion app (desktop) | + Luanti/VoxeLibre/Mod installer & manager. "Play" button launches Luanti. Screen sharing, nearby player list, voice controls, overlay. |
| 0.3.x | Launcher + Companion app (desktop + web + mobile) | + Login, registration, profile management. |
| 0.4.x | Same | + Stripe Checkout, subscription management, billing portal. |
| 0.5.x | Same | + Organization panel: create org, invite members, manage roles and seats. |
| 0.7.x | Same | + Knowel progress view, tree state visualization (mirror of in-game tree). |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Companion App (Flutter)             │
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ Voice    │  │ Screen   │  │ UI Layer          │  │
│  │ Engine   │  │ Share    │  │ (overlay, panels, │  │
│  │          │  │ Engine   │  │  auth, org, etc.) │  │
│  └────┬─────┘  └────┬─────┘  └────────┬──────────┘  │
│       │              │                 │             │
│  ┌────▼──────────────▼─────────────────▼──────────┐  │
│  │              LiveKit Client SDK                │  │
│  │         (livekit_client package)               │  │
│  └────────────────────┬───────────────────────────┘  │
│                       │                             │
│  ┌────────────────────▼───────────────────────────┐  │
│  │             Backend Relay Sync                 │  │
│  │   (WebSocket to server-svc for positions)      │  │
│  └────────────────────┬───────────────────────────┘  │
│                       │                             │
│  ┌────────────────────▼───────────────────────────┐  │
│  │         Backend Client (HTTP/REST)             │  │
│  │   auth, tenant, progress, knowel APIs          │  │
│  └────────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────────┐│
│  │           Launcher / Installer Engine            ││
│  │  Detect → Install → Configure → Launch Luanti   ││
│  └──────────────────────────────────────────────────┘│
│                                                     │
└─────────────────────────────────────────────────────┘
         │                    │
         │ WSS               │ HTTP / WSS
         ▼                    ▼
   LiveKit Server       Backend Services
   (GCE)                (auth-svc, server-svc, etc.)
```

---

## Spatial Voice Engine

### Connection Flow

1. App starts → authenticates via `/auth/login` using Firebase Auth token.
2. Obtains LiveKit room token via `POST /auth/livekit-token` (or hardcoded in 0.1.x).
3. Connects to backend WebSocket relay (server-svc) to receive live player positions.
4. Connects to LiveKit server via WebSocket (WSS) and publishes local mic track.
5. Subscribes to remote audio tracks from other participants.

### Spatial Audio Algorithm

The companion app reads its own position and remote player positions from the WebSocket backend relay. Volume is calculated client-side:

```dart
double calculateVolume(double distance, double maxRadius) {
  if (distance >= maxRadius) return 0.0;
  if (distance <= 1.0) return 1.0;
  // Inverse square falloff for natural spatial feel
  return (1.0 - (distance / maxRadius)).clamp(0.0, 1.0);
}
```

- `maxRadius`: configurable, default 64 blocks.
- Volume is applied per-track via LiveKit SDK's `RemoteAudioTrack.setVolume()`.
- Position update interval: roughly ~500ms (pushed by backend).

### Player Identity Mapping

LiveKit participants are identified by exactly their `luanti_username` (which corresponds to both their backend identity and their in-game Luanti avatar name).

---

## Screen Sharing Engine

> **Scope Note:** Screen capture and publishing is restricted to the **Desktop** version of the app. Mobile and Web versions may view screens, but cannot publish them contextually within the spatial game. Voice chat is also optimized for Desktop, since Mobile users cannot run the standard PC game client concurrently.

### Capture (0.2.x)

- Uses LiveKit's screen capture API: `localParticipant.setScreenShareEnabled(true)`
- On desktop: captures the entire screen or a selected window.
- Quality target: 1080p at 30fps minimum.
- Encoding: VP8 or H264 (LiveKit handles codec negotiation).

### Viewing

- When a remote participant publishes a screen share track, it appears in the companion app's screen panel.
- Only tracks from players within proximity radius are displayed.
- UI shows: sharer's name, full-screen toggle, close button.

### Mod Notification

- When screen sharing starts/stops, the companion app notifies the backend via REST or WS.
- The backend then pushes this status to the Luanti server-side mod, which renders an in-game indicator over the sharing player's avatar.

---

## Backend Relay Bridge

Instead of a local HTTP CSM bridge, the companion app communicates with the Luanti mod strictly via the Cloud Backend:

| Data Flow | Mechanism |
|-----------|-----------|
| Player positions (Luanti → App) | Luanti Server-side Mod POSTs to backend -> Backend broadcasts to App via WebSocket. |
| Voice/Screen status (App → Luanti) | App notifies backend -> Backend forwards to Luanti Server-side Mod. |

### Sync Strategy

- The app stays continuously connected to the backend WebSocket.
- Position data is used to: calculate voice volumes, filter screen shares by proximity, update nearby player list.
- If the game server is offline, the app shows a "waiting for game" state.

---

## Launcher / Installer Engine (0.2.x+)

Starting in 0.2.x, the Companion App is the **only thing the user downloads**. It manages the full Luanti stack.

### First Run Wizard

1. **Detect Luanti** — scans known OS paths for existing installations:
   - Windows: `%APPDATA%\Minetest`, `%LOCALAPPDATA%\Programs\Luanti`, winget registry
   - macOS: `~/Library/Application Support/minetest`, Homebrew
   - Linux: `~/.minetest`, system packages (`dpkg -l`, `rpm -qa`)
2. **Install Luanti** (if not found) — uses OS package manager:
   - Windows: `winget install Luanti.Luanti`
   - macOS: `brew install --cask luanti`
   - Linux: `apt install luanti` / `flatpak install`
3. **Install VoxeLibre** — downloads latest release into Luanti's `/games/` directory.
4. **Install Trivium Mod** — copies mod into Luanti's `/mods/` directory. Auto-enables it.
5. **Verify** — runs a health check (Luanti binary exists, game+mod are in correct paths).

### Adoption of Existing Installations

If the user already has Luanti, VoxeLibre, or the Trivium Mod installed (e.g. beta testers from 0.0.x–0.1.x), the wizard detects them and **adopts** the existing installation without reinstalling. It only installs or updates components that are missing or outdated.

### Update Management

On each app launch:
- Checks mod version against the latest bundled version → auto-updates if newer.
- Checks VoxeLibre version → prompts update if major version differs.
- Luanti updates are left to the OS package manager (winget upgrade, brew upgrade, etc.).

### Launch Flow

```
[▶ Play] button clicked
    ↓
Companion App launches Luanti with args:
  luanti --address play.trivium.world --port 30000 --go
    ↓
Companion App stays running in background:
  - Voice spatial engine active
  - Screen share ready
  - WebSocket relay connected
  - Overlay visible (optional)
    ↓
When Luanti closes → Companion App returns to home screen
```

---

## UI Components

### 0.1.x — Voice Client

Minimal UI:
- Microphone toggle (mute/unmute)
- Connection status indicator (connected/disconnected)
- Server address input
- Volume indicator (showing who's talking)

### 0.2.x — Launcher + Companion App

- **Home screen**: [▶ Play] button, server status, connection info.
- **Setup wizard** (first run): detect/install Luanti, VoxeLibre, mod.
- **Nearby player list**: names, distance, voice/sharing status indicators.
- **Voice controls**: mute self, volume slider, push-to-talk option.
- **Screen share panel**: view shared screens, start/stop own share.
- **Status overlay**: optional always-on-top mini window showing nearby players.
- **Settings**: Luanti path override, update check toggle.

### 0.3.x — Auth

- **Login screen**: email/password via Firebase Auth.
- **Registration screen**: create account (leads to Stripe Checkout in 0.4.x).
- **Profile view**: display name, email, plan status.

### 0.4.x — Subscriptions

- **Stripe Checkout**: embedded or redirect to Stripe for payment.
- **Plan view**: current plan, renewal date, payment method.
- **Billing portal**: link to Stripe Customer Portal.

### 0.5.x — Organizations

- **Create organization**: name, billing email.
- **Member management**: invite by email, assign roles, remove members.
- **Seat management**: current seats used, purchase more.
- **Team view**: members list with roles and status.

---

## Platform Matrix

| Platform | 0.1.x | 0.2.x | 0.3.x+ |
|----------|-------|-------|--------|
| Windows | ✅ | ✅ | ✅ |
| macOS | ✅ | ✅ | ✅ |
| Linux | ✅ | ✅ | ✅ |
| Web | ❌ | ❌ | ✅ |
| Android | ❌ | ❌ | ✅ |
| iOS | ❌ | ❌ | ✅ |

Desktop is the primary platform (runs alongside Luanti as its launcher). Web and mobile are added in 0.3.x for account management. Voice/screen optimized for desktop only.

---

## Dependencies

| Dependency | Package | Purpose |
|-----------|---------|---------|
| LiveKit Flutter SDK | `livekit_client` | Voice chat, screen sharing (WebRTC SFU) |
| Firebase Auth | `firebase_auth` | Authentication (0.3.x+) |
| HTTP client | `http` or `dio` | Backend API calls |
| Stripe | `flutter_stripe` | Payment integration (0.4.x+) |
| Window manager | `window_manager` | Desktop window control, overlay mode |
| Process | `process_run` (dart:io) | Launch and monitor Luanti process |
| Path provider | `path_provider` | Detect OS-specific Luanti directories |

---

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Luanti path | (auto-detected) | Override for custom Luanti installation path |
| LiveKit server URL | `wss://livekit.trivium.world` | LiveKit SFU server |
| Backend URL | (none until 0.3.x) | Backend API base URL |
| Voice max radius | 64 | Maximum distance for voice (blocks) |
| Screen share max radius | 32 | Maximum distance to see shared screens |
| Auto-update mod | true | Check and update Trivium Mod on launch |

---

## Open Questions

- Whether the overlay mode (always-on-top mini window) is technically feasible across all desktop platforms.
- Push-to-talk vs always-on microphone as default.
- How to handle multiple monitors for screen sharing target selection.
- Whether to support window-specific capture (share one window) vs full screen.
- Luanti installation on Linux: preference between apt, flatpak, or AppImage.
- Whether to bundle a specific Luanti version instead of relying on OS package managers.
