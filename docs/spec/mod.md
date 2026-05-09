# Spec — Trivium Mod

> Status: draft
> Version: 0.1.0
> Releases: 0.0.x (text chat), 0.1.x (position API), 0.2.x (screen indicator), 0.7.x (tree + knowels)

---

## Summary

The Trivium Mod is a Lua mod for Luanti running on top of VoxeLibre. It provides proximity text chat (as a fallback to the companion app's spatial voice), exposes player state to the backend relay, renders in-game indicators, and in later releases implements the Tree of Noesis and knowel system within the 3D world.

The mod runs on both the client and server side of Luanti.

**Repo path:** `code/mod/`

---

## Responsibilities

| Responsibility | Release | Side |
|---------------|---------|------|
| Proximity text chat (fallback) | 0.0.x | Server + Client |
| Player position relay via backend HTTP push | 0.1.x | Server |
| Screen sharing indicator over avatar | 0.2.x | Client |
| Backend auth verification | 0.3.x | Server |
| Subscription plan verification | 0.4.x | Server |
| Organization membership awareness | 0.5.x | Server |
| In-game Tree of Noesis | 0.7.x | Server + Client |
| In-game knowel system | 0.7.x | Server + Client |
| In-game quizzes | 0.8.x | Server + Client |

---

## Proximity Text Chat (Fallback)

Text chat serves as a secondary communication channel when spatial voice (provided by the companion app) is unavailable — for example, when a player has no microphone or the companion app is not running.

### Behavior

- Player sends a chat message via the standard Luanti chat input.
- The mod intercepts the message before it reaches the default broadcast handler.
- The mod calculates the distance between the sender and every other connected player.
- Only players within the configured radius receive the message.
- Messages outside radius are silently dropped for that recipient.

### Radius Levels

| Level | Radius | Trigger |
|-------|--------|---------|
| Whisper | ~8 blocks | `/w <message>` or `/whisper <message>` |
| Talk | ~32 blocks | Default (no prefix) |
| Shout | ~128 blocks | `/s <message>` or `/shout <message>` |

Radii are configurable via mod settings (`trivium.chat_radius_whisper`, `trivium.chat_radius_talk`, `trivium.chat_radius_shout`).

### Implementation Approach

```lua
-- Server-side: intercept outgoing chat
minetest.register_on_chat_message(function(name, message)
    local sender = minetest.get_player_by_name(name)
    if not sender then return true end

    local pos = sender:get_pos()
    local radius, prefix = parse_chat_level(message)
    local clean_msg = strip_prefix(message)

    for _, player in ipairs(minetest.get_connected_players()) do
        local target_pos = player:get_pos()
        local dist = vector.distance(pos, target_pos)
        if dist <= radius then
            minetest.chat_send_player(player:get_player_name(),
                format_message(name, clean_msg, prefix))
        end
    end

    return true  -- suppress default broadcast
end)
```

---

## Backend Relay API (Position Exposure)

Starting in 0.1.x, the server-side mod exposes player states to the companion apps by pushing them directly to the backend (`server-svc`), which relays them to the flutter clients. Local CSM HTTP polling is bypassed completely due to Luanti sandbox restrictions.

### Mechanism

The server-side mod hooks into the server tick (`minetest.register_globalstep`) and performs a batch HTTP POST of all player positions every ~500ms to the backend.

### Payload Example

```json
{
  "server_id": "uuid",
  "timestamp": 1717840000,
  "players": [
    {
      "name": "carlos_dev",
      "position": { "x": 120.5, "y": 15.0, "z": -340.2 }
    },
    {
      "name": "alice_premium",
      "position": { "x": 125.0, "y": 15.0, "z": -338.0 }
    }
  ]
}
```

### Design Notes

- The server-side mod pushes all player positions to the backend, enabling 100% server-authoritative positional tracking.
- Mod update interval: 500ms (to prevent overwhelming the Dart backend).
- The Dart backend then broadcasts this state to the relevant Companion App WebSockets.

---

## In-Game Indicators

### Screen Sharing Indicator (0.2.x)

When the companion app notifies the backend that a player is sharing their screen, the backend notifies the server-side mod, which renders a visual indicator above that player's avatar.

- Indicator: a floating icon (screen symbol) above the player's nametag.
- Implemented via HUD element or entity attachment.
- Driven by the periodic sync payload coming back from the backend.

### Voice Activity Indicator (0.1.x)

Optional: show a speaker icon above players who are currently speaking.

- Tracked by LiveKit, relayed to backend, and synced back to the mod.
- The mod reads this and attaches a HUD indicator.

---

## Backend Integration

### Auth Verification (0.3.x)

- On player join, the server-side mod sends a join token (or username if local) to the backend.
- Endpoint: `GET {backend_url}/auth/verify?join_token={token}`
- If the player is not registered, the mod can show a message or restrict features.

### Subscription Verification (0.4.x)

- On player join and periodically, the mod checks the player's plan.
- Endpoint: `GET {backend_url}/auth/verify`
- Premium and Org features are gated based on the response.

### Organization Awareness (0.5.x)

- The mod queries which organization a player belongs to.
- Used for: org-specific chat channels, permissions, shared workspaces.

---

## In-Game Tree of Noesis (0.7.x)

### Planting

- Premium players can plant their Tree of Noesis at a chosen location.
- The tree is a custom node with sakura appearance.
- One tree per player per server.

### Growth

- The tree starts as a sapling.
- Each completed knowel adds visual growth: branches, leaves, petals.
- Tree state is persisted via progress-svc.

### Interaction

- Right-clicking the tree opens a formspec (Luanti UI) showing:
  - Knowel list (acquired, in-progress, available)
  - Skill tree visualization (branches, nodes)
  - Achievements and masteries

### Petals

- Falling particle effects around the tree.
- Each petal represents an available knowel not yet integrated.
- Density of petals correlates with available learning opportunities.

---

## In-Game Knowel System (0.7.x–0.8.x)

- Knowels appear in the world as interactive objects or stations.
- Completing a knowel triggers a quiz (0.8.x).
- Progress is synced to progress-svc via direct REST calls.
- Progressive unlocking: advanced knowels require prerequisite completion.

---

## Installation & Distribution

- **0.0.x (Dev/Testers)**: Direct ZIP download from GitHub Releases. Manual installation.
- **0.1.x (Testers)**: Still manual installation alongside the voice client.
- **0.2.x+ (Public/Desktop)**: The Companion App acts as launcher and manages the full stack. On first run, its setup wizard auto-installs Luanti (via winget/brew/apt), VoxeLibre, and the Trivium Mod. Existing installations from 0.0–0.1 testers are detected and adopted without reinstalling. Mod auto-updates on each app launch.

---

## Configuration

All mod settings via `minetest.conf` or `settingtypes.txt`:

| Setting | Default | Description |
|---------|---------|-------------|
| `trivium.chat_radius_whisper` | 8 | Whisper radius in blocks |
| `trivium.chat_radius_talk` | 32 | Talk radius in blocks |
| `trivium.chat_radius_shout` | 128 | Shout radius in blocks |
| `trivium.backend_relay_url` | (none) | Backend WebSocket/HTTP URL for pushing state |
| `trivium.state_push_interval` | 0.5 | Seconds between server-side state broadcasts |
| `trivium.backend_url` | (none) | Backend REST API base URL (0.3.x+) |

---

## Dependencies

| Dependency | Type | Purpose |
|-----------|------|---------|
| Luanti 5.x | Runtime | Game engine |
| VoxeLibre | Runtime | Base game providing world, biomes, inventory |
| server-svc | HTTP/WSS | Receives player telemetry, broadcasts to companion apps |
| Backend APIs | HTTP (0.3.x+) | Auth, progress, subscription verification |

---

## Open Questions

- How to handle the tree formspec UI for skill tree visualization (custom formspec or external web view).
- Whether knowel stations are nodes, entities, or formspec-based interactions.
