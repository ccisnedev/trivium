# Spec — World: Trivium

> Status: draft
> Version: 0.4.0
> Purpose: define the Trivium digital world, its two-component technical architecture (mod + companion app) and its capabilities as a space for learning, remote work and virtual living.

---

## Summary

**Trivium** is the name of the digital world where three dimensions of experience converge:

1. **Learning** — acquiring knowels, verified capabilities, within an immersive environment
2. **Remote work** — 3D virtual office with spatial voice chat and screen sharing
3. **Virtual world** — a habitable space to explore, build, play and live

It is not just a map, a lobby or a skin over an educational app or videoconference tool. It is a persistent world where internet metaphors (forum, room, post, office, classroom) materialize as real navigable places.

From the already defined cosmology, Trivium relates as follows:

- **Ensō** is the ritual access (the zen circle traced to enter)
- **Trivium** is the habitable world
- **Viridian** is the green light on the horizon that guides
- **The Tree of Noesis** is the cosmic structure of knowledge
- **Petals** are knowel possibilities
- **Knowels** are verified capabilities

---

## World Name

### Name

**Trivium**

### The Word: Meanings and Foundation

#### Etymology

Trivium comes from Latin:

- **tri** — three
- **via** — road, way

Literally: the place where three roads cross.

#### Meaning 1 — Roman urbanism: the crossroads

In the Roman city, a trivium was a point where three roads converged. It was not a final destination, but a node of transit and encounter. People stopped there to talk, exchange news, trade and observe.

The trivium was a space of natural convergence: it belonged to no one in particular, but everyone used it. It was a public space by function, not by decree.

From this meaning also derives the word trivialis: what was found at the crossroads, the common, the accessible to all. Over time, trivialis degraded to "trivial" (unimportant), but the original meaning was different: what is available to anyone, what is shared, what requires no special permission.

#### Meaning 2 — Medieval education: the three arts of thought

In the medieval educational tradition, the Trivium was the first block of the seven liberal arts. It contained exactly three disciplines:

1. **Grammar** — mastering language and expressing with precision
2. **Logic (Dialectic)** — reasoning correctly, distinguishing valid from invalid
3. **Rhetoric** — persuading, communicating, acting on knowledge

The Trivium did not teach subject matter. It taught the fundamental tools of thought and communication. Without mastering the Trivium, the student could not access the Quadrivium (arithmetic, geometry, music, astronomy).

This is central to the project: the medieval Trivium was not a catalog of information, but a system of capabilities. The three disciplines formed the foundation without which no other knowledge could be properly articulated. That idea is exactly what a knowel represents: not content viewed, but demonstrable capability.

#### Meaning 3 — Ternary structure

Trivium inherently implies "three." For this project, the three crossing roads are:

1. **Learning** — knowels, verified capabilities, Tree of Noesis
2. **Work** — virtual office, collaboration, remote productivity
3. **World** — exploration, play, virtual life, spatial presence

The name does not need to explain the three; it contains them.

#### Additional trivia

- The Trivium as an educational system was formalized by authors such as Martianus Capella (5th century), Boethius (6th century) and Cassiodorus (6th century), and codified during the Carolingian Renaissance by Alcuin of York under Charlemagne's patronage.
- The seven liberal arts (Trivium + Quadrivium) were the dominant educational framework in Europe for almost a millennium.
- The word "trivial" (what is found at the crossroads) has a direct etymological kinship, but the original meaning was not pejorative: it was "accessible to all," not "without value."
- In the classical tradition, the Trivium was considered the art of the word (grammar, logic, rhetoric) and the Quadrivium the art of number (arithmetic, geometry, music, astronomy).
- Dorothy Sayers, in her essay "The Lost Tools of Learning" (1947), argued that the Trivium should be recovered as the basis of modern education, because it teaches how to think before teaching what to think.

### Why This Name

- names exactly the confluence of three dimensions without having to enumerate them
- has precise and non-decorative educational foundation
- sounds professional and commercial without sounding corporate
- is pronounced the same in Spanish, English, Italian, French and Portuguese
- needs no translation: recognizable in any language of Latin tradition
- clearly separates the habitable world from **Viridian**, which remains horizon and promise

### Function of the Name

Trivium must communicate that this space is the crossroads where learning, work and virtual life converge.

It is not a knowledge museum. It is not just a video call with avatars. It is not just a game. It is the point where the three roads meet.

---

## World Objective

Trivium exists to be the crossroads where learning, remote work and virtual life converge in a single habitable space.

Objectives:

- serve as the primary space where Knowel Adventure takes place
- function as a 3D virtual office for remote teams
- enable training through knowels within a playable environment
- blend exploration, collaboration and capability demonstration
- make the structure of knowledge feel like a place, not just an interface
- materialize internet metaphors (forum, room, post, office) as navigable spaces

In Trivium, a knowel is not presented solely as content to consume. It must be experienced as a challenge, guided activity, accompanied practice or demonstrable capability.

---

## Technical Architecture

Trivium is composed of **two software pieces** that work together:

### Component 1 — Luanti Mod (3D world)

| Aspect | Detail |
|--------|--------|
| Engine | **Luanti** (formerly Minetest) |
| Base game | **VoxeLibre** (formerly MineClone2) |
| Format | **Mod** on VoxeLibre |
| Language | Lua (Luanti mod API) |

The mod is responsible for everything that happens within the 3D world.

#### What VoxeLibre provides without needing to build it

VoxeLibre already provides an explorable, multiplayer, modifiable open world. This includes:

- procedural terrain generation with biomes, caves, oceans and structures
- inventory system, crafting and building
- day/night cycle, weather, lighting
- first-person movement, swimming, flight (creative mode)
- multiplayer with dedicated servers
- permissions system and area protection
- mobs, fauna, basic flora

None of this needs to be built. It is used as-is as the base for the habitable world.

#### What the Trivium mod must provide

1. **Proximity chat**
   - **Voice (primary)**: spatial voice with volume proportional to distance, handled by the companion app via LiveKit
   - **Text (fallback)**: text messages visible only to players within a configurable radius, for when voice is unavailable
   - reinforces the sense of spatial presence and co-location
   - may include levels: whisper (short radius), talk (medium radius), shout (wide radius)

2. **In-game Tree of Noesis**
   - the player can plant and grow their own Tree of Noesis within the world
   - the tree has a sakura appearance: elegant trunk, wide crown, petals falling as particles
   - the tree visually reflects the player's progress: more acquired knowels = more branches, more blooming
   - interacting with the tree gives access to the knowel list and skill tree
   - the skill interface follows the RPG skill tree model: connected nodes, specialization branches, progressive unlocking
   - falling petals represent possibilities of knowels not yet integrated

3. **In-game knowel system**
   - knowels appear within the world as opportunities for practice, discovery and verification
   - the player can see their list of acquired, in-progress and available knowels
   - progress is reflected in both the personal tree and the inventory/skill UI

4. **Companion app integration**
   - the server-side mod pushes player state (positions, nearby players) to the backend relay over HTTP
   - the companion app receives this state via WebSocket from the backend
   - when a player activates screen sharing or voice chat from the companion app, the backend relays this status to the mod, which visually reflects it (indicator over avatar, sharing zone)

### Component 2 — Companion App (Flutter)

The companion app is a native cross-platform application built in **Flutter** that serves as the **single entry point and launcher** for the Trivium experience, managing the installation and lifecycle of Luanti, VoxeLibre and the Trivium Mod (from 0.2.x onward).

| Aspect | Detail |
|--------|--------|
| Framework | **Flutter** |
| Platforms | Windows, macOS, Linux, Android, iOS |
| Model | App that accompanies the Luanti session, similar to Discord or Gather's companion app |

#### Companion app responsibilities

1. **Screen sharing**
   - captures and transmits the user's screen to other nearby players or the group
   - allows viewing another player's shared screen in a window or panel
   - use cases: tutoring, pairing, debugging, walkthroughs, knowel review
   - the experience should feel integrated with the Trivium session, not like a disconnected external tool

2. **Proximity voice chat**
   - spatial voice that depends on the player's position within the world
   - nearby players are heard with volume proportional to distance
   - moving away causes voice to fade and disappear
   - also allows group or room channels for meetings and workshops

3. **Status overlay**
   - shows contextual world information: nearby players, available knowels in the zone, tree state
   - can show mod notifications: new petals, unlocks, invitations

4. **Authentication and profile**
   - account management, subscription and user profile
   - knowel progress synchronization with the backend

#### Why a separate companion app instead of everything inside the mod

- Luanti has no native screen capture or video/audio streaming capabilities between clients
- building video/voice inside the voxel engine would be reinventing the wheel with worse results
- the companion app model is validated by Discord (overlay + voice + screen) and Gather (web app + 2D world)
- separating responsibilities keeps the mod lightweight and focused on the in-game experience
- Flutter enables covering desktop and mobile with a single codebase

### How They Work Together

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│      Luanti + VoxeLibre     │     │      Companion App (Flutter) │
│         + Trivium Mod       │     │                              │
│                             │     │  • Voice chat (proximity)    │
│  • Open 3D world            │◄───►│  • Screen sharing            │
│  • Proximity chat (text) │     │  • Status overlay            │
│  • In-game Tree of Noesis   │     │  • Profile and subscription  │
│  • Knowel system            │     │                              │
│  • Status indicators        │     │                              │
└─────────────────────────────┘     └──────────────────────────────┘
         │                                      │
         └──────────┬───────────────────────────┘
                    │
            ┌───────▼────────┐
            │    Backend     │
            │  (API, auth,   │
            │  knowels,      │
            │  progress)     │
            └────────────────┘
```

The mod and companion app communicate locally. Both connect to a shared backend for persistence, authentication and progress synchronization.

---

## World Capabilities

### 1. Proximity chat

Trivium must include **spatial voice chat** as a central social mechanic. Text chat exists as a fallback.

Implementation:

- **Voice (companion app, primary):** spatial audio with volume proportional to distance. The core communication primitive.
- **Text (mod, fallback):** messages visible only to players within a configurable radius. For when voice is unavailable.

Requirements:

- communication must depend on spatial proximity between players
- the world must favor local conversations, situated tutoring and small group coordination
- the system must reinforce the sense of presence and co-learning within the shared space

### 2. Screen sharing

Trivium must offer the **ability to share screens** through the companion app.

Use cases:

- a learner shares their screen to show a real problem
- a mentor shares their screen to explain a procedure, code or tool
- a small group watches a demonstration in context while remaining in the world

Requirements:

- screen sharing must feel like part of the Trivium experience
- must serve for tutoring, pairing, debugging, walkthroughs and joint knowel review
- the companion app handles capture and transmission; the mod can visually reflect the state

### 3. In-game Tree of Noesis

Within the world, the player can **plant and cultivate their own Tree of Noesis**.

Behavior:

- sakura appearance with petals falling as particles
- the tree grows and blooms as the player acquires knowels
- interacting with the tree gives access to:
  - their knowel list (acquired, in-progress, available)
  - their skill tree (RPG-style)
  - their specialization branches
  - their achievements and masteries
- falling petals represent possibilities of knowels not yet integrated
- a neglected tree (knowels not reviewed) may lose blooming

This tree is the central interface for the player's progress within the world.

### 4. Explorable open world

The open world **already exists thanks to Luanti + VoxeLibre**. There is no need to build it.

What VoxeLibre already provides:

- infinite procedural terrain with varied biomes
- free building and terrain modification
- multiplayer with dedicated servers
- day/night cycle, weather, dynamic lighting
- fauna, flora, resources, crafting
- permissions system and area protection

What the Trivium mod adds on top:

- knowledge stations, tutoring zones, practice spaces
- signage and pedagogical routes
- visual indicators of companion app state (who is sharing screen, who is talking)
- integration with the knowel and progress system

---

## Knowel Adventure in Trivium

Trivium is the place where Knowel Adventure happens in a playable way.

This implies:

- users come to the world to learn, not just to socialize
- knowels must appear within the world as opportunities for practice, discovery and verification
- progress must feel tied to territory, routes and interactions between players

### Pedagogical Translation

Within Trivium:

- **petals** can manifest as learning opportunities, invitations or emergent routes
- **knowels** must end in a capability demonstrated by the user
- training must be possible individually or accompanied
- the world must allow moving from an indeterminate situation to a clearer, more operable resolution

### Playable Translation

Within Trivium, learning can take forms such as:

- knowledge stations
- guided routes
- pedagogical missions
- collaborative workshops
- mentor-learner practice spaces
- demonstration and verification zones

The exact form can evolve, but the rule is stable: the knowel must feel like a conquered capability, not passively consumed content.

---

## World Design Principles

### 1. The world is a spatial pedagogy

The structure of learning must be inscribed in space, not just in menus.

### 2. Social presence is not decorative

Spatial voice chat and screen sharing are not extras. They are infrastructure for learning with others.

### 3. Knowledge must be demonstrable

Every important knowel within Trivium must lead to a form of verification, performance or observable application.

### 4. Fantasy must serve clarity

The symbolic layer of Ensō, Viridian and Noesis must reinforce the pedagogical experience, not distract from it.

### 5. The world must invite staying

Trivium has to feel alive enough that users want to inhabit it, not just enter, complete a task and leave.

---

## Entry Scene in Relation to Trivium

Conceptual sequence:

1. The user traces the Ensō.
2. Crosses into Trivium.
3. Arrives at the dark coast.
4. Sees Viridian's green light on the horizon.
5. Receives petals from the Tree of Noesis carried by the tide.
6. Begins their Knowel Adventure journey within the world.

Important decisions:

- **Viridian is not Trivium** — Viridian remains horizon, direction and promise
- **Ensō is not the world** — Ensō is the ritual gesture of entry; Trivium is the world
- Trivium is the world where the user inhabits, learns, works and collaborates

---

## What a User Must Be Able to Do in Trivium

- enter the world and orient themselves
- meet other players in a persistent space
- converse locally through spatial voice and proximity text chat
- share their screen or see another person's screen in learning contexts
- discover knowels
- practice knowels
- demonstrate acquired capabilities
- progress along training routes within the world

---

## What Trivium Must Not Be

- must not be an empty lobby before the real app
- must not be a generic sandbox without pedagogy
- must not be an LMS disguised as a voxel world
- must not be just a video call with avatars
- must not rely only on text and menus to teach
- must not separate the social from the pedagogical nor work from learning

---

## Open Questions

- whether knowels will be represented as quests, spaces, NPCs, stations or a combination
- whether user progress will live entirely within Trivium or synced with external Knowel systems
- whether Trivium will have specific biomes and regions (pedagogical, work, social) from the start or grow from a single initial coastline

---

## Success Criterion for This Direction

The direction works if a user can say:

> I entered a real, habitable, shared world. I could talk to others near me, show what I was doing, learn a concrete capability and feel that learning happened inside the world, not outside it.

If Trivium is perceived as just a visual layer on top of a course system or a video call disguised as a world, this direction fails.