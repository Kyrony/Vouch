# Vouch - MVP Game Design Document

Concise reference for the design decisions this scaffold was built around.
If code and this doc ever disagree, this doc wins for *intent* - file a
TODO and fix the code.

## One-line pitch

8 players wake up alone in an industrial bunker, split into 4 rival
factions - plus, some games, one secret **Puppet Master** who isn't on
anyone's side. Nobody knows who's on their team. Escape together, or
don't. One of you might be trying to make sure nobody does.

## Setting

Industrial bunker / underground facility. Cold, functional, no frills -
graybox rooms, exposed fixtures, pipes and wires, one working light per
room, a phone, an escape point, a security camera, a ladder.

## Home screen & Settings

- Landing screen ("Home") offers **Play / Settings / Character / Exit**.
  Character is still a stub panel; **Settings is fully functional**:
  - **Key remapping** for move (WASD)/jump/interact/destroy - click a
    binding, press any key/mouse button/gamepad button to rebind it.
    "Reset" restores that action's project default.
  - **Mouse/look sensitivity** slider (0.1x-4x multiplier).
  - **Audio**: master volume (wired to the engine's real "Master" bus)
    and an SFX volume slider (stored, but there are no SFX in the
    project yet, so it's currently inert - see `SettingsManager.gd`).
  - Everything persists locally via `ConfigFile` (`SettingsManager.gd`)
    and is never networked - every peer keeps their own settings.
- **Play** opens the host/join flow. A live **joined-player list**
  (name + peer id) is shown below the host/join controls and updates as
  peers connect/disconnect (`NetworkManager.lobby_roster_updated`,
  broadcast to everyone). This is pre-match "who's here" information
  only - no faction/role data, consistent with the privacy rule below.
  Once hosting, a **"Match spawn odds"** panel also appears - see "Host
  spawn odds" below.

## Factions

- MVP: **4 factions, 2 players each** (4v4 flavor) plus, some games, **1
  Puppet Master** - see "Puppet Master" below for exactly when one spawns.
- Factions ship with a color + codename: **Red Vipers**, **Blue Ash**,
  **Green Hollow**, **Yellow Sparks**.
- Architecture supports **N factions** - `FactionData.active_faction_count`
  and every faction-aware system (`GameState`, `EscapeSystem`, faction
  assignment) loop over `get_active_factions()` rather than hardcoding a
  count. Changing that one number (once it's exposed as a lobby setting,
  which it isn't yet) gets you 3v3v3, 4v4v4v4, etc. without touching
  gameplay logic.
- **A player only ever learns their own faction.** There is no roster/
  teammate-list UI anywhere in the client, on purpose - `GameState` keeps
  the full roster server-side only, and the only faction-related value a
  client ever receives over the network is its own `local_faction_id`
  (see `NetworkManager._client_receive_faction`, sent as a targeted
  unicast RPC, never broadcast).

## Rooms - floor-plan templates

Each player spawns **alone** in their own procedurally-built room
("RoomPod" - see `scripts/room_pod.gd`), assembled from one of **20
James floor-plan templates** on a 1 ft = 1 Godot unit grid
(`scripts/systems/floor_plan_templates.gd`). Plans 01–14 are single-story;
15–20 are two-story with a shared stair shaft. A server-side
`floor_plan_id` is baked into spawn data so every peer builds the same
layout.

- **Theme** - one of three palettes: **Bedroom**, **Utility Room**,
  **Creepy Basement** (rolled per room from seed).
- **Layout** - living / bedroom / bath / hall / closet zones with
  interior and exterior door openings (~3.5 ft wide).
- **Escape varies**: most rooms escape through the **south entry door**;
  some use a **vent** in bath/closet instead. **Exactly one room may
  have no escape** - the Puppet Master.
- **Optional hazards**: water valve (mystery flood control), electrical
  box, code-locked escape (host odds), **fireplace + floor gas riser**
  (clue book sometimes spawns inside), **floor drains** and **exhaust
  vents**, **physics flammables** (books/papers/ladders via `FireSystem`).

### World layout (underground escape hub)

- Each room's escape door/vent opens with a **swing/slide animation** —
  no teleport through transitions. Walk through the opening into a
  **horizontal escape hall**, then a **vertical rise** into a shared
  central shaft; **Outside** sits at the top (`EscapeHub` + `Outside`).
- Rooms **rotate** so their escape faces the hub at world origin.
- Walls use **lintels** above door gaps so rooms stay enclosed to the
  ceiling; escape tunnels are capped with ceilings too.

### In-match UI

- **Esc** opens a pause menu: Resume, Settings (hint), Exit to Home,
  and **Debug GUI** (dev — **REMOVE DEBUG GUI FROM PAUSE MENU BEFORE
  FINAL LAUNCH**).
- **Binary terminal puzzle** (~40% spawn): flip bits to match a target
  decimal; success slides a bookcase and activates a wall monitor with a
  live peek into another player's room.

TODO(post-MVP): richer decoration, per-plan prop sets.

Headless floor-plan validation: `VOUCH_FLOOR_PLAN_TEST=1 godot4 --headless --path .`
Headless match spawn validation: `VOUCH_MATCH_SPAWN_TEST=1 godot4 --headless --path .`

## Puppet Master

- A **fifth, independent role**, not part of any rival faction.
- **Spawn rules**: only possible with **4 or more players**, and even
  then only a **50% chance** per eligible match
  (`PuppetMasterSystem.MIN_PLAYERS_FOR_PUPPET_MASTER` /
  `SPAWN_CHANCE`) - most matches below 4 players, or that lose the coin
  flip, have no Puppet Master at all and just play as a normal N-faction
  escape match.
- Their room is always a **perfect, unadorned box** (no closet/hallway/
  vent connector module) with a few decorative **monitor screens** on
  the wall - see `RoomPod._build_monitors()`. The FUNCTIONAL camera feeds
  are a PM-only HUD panel, not these world-space screens, so anyone who
  wanders into the PM's room (nothing stops them) can't peek at the live
  feeds just by looking at the wall.
- **Goal**: eliminate every other player before any faction fully
  escapes.
- **Any control in the Puppet Master's own room must never affect their
  own room** - guaranteed, not just likely, by `LinkGraph`'s pairing
  algorithm (see "Mystery controls" below): the same guarantee actually
  applies to every room's controls, not just the PM's.
- At match start they're granted:
  - **Camera feeds** into a small number of other rooms (a real
    `SubViewport` + `Camera3D` looking into that room's world position -
    see `Player.gd`'s camera panel), plus a **sabotage** button per feed
    that reuses `LinkGraph`'s existing per-room effect nodes (e.g.
    flicking that room's light).
  - The ability to **eliminate** ANY other room's occupant (a
    host-authoritative stub kill switch, `PuppetMasterSystem`) -
    deliberately NOT limited to only the camera-equipped rooms, since
    "eliminate everyone" would be impossible otherwise. Camera/sabotage
    access is the "few rooms" the brief asked for; elimination reach is
    full, matching the stated win condition.
- **Win/lose rule** (the simple rule proposed for this scaffold):
  - Puppet Master **WINS** if every other player is eliminated before
    any faction fully escapes.
  - Otherwise, the first faction to fully escape wins as normal, and the
    Puppet Master loses.
  - Whichever happens first ends the match exactly once
    (`GameState.phase` flips to `MATCH_OVER`; see `EscapeSystem._check_for_win`
    and `PuppetMasterSystem._check_for_pm_win`, both guarded against
    double-firing).
- None of the Puppet Master's targets, camera feeds, or even their role
  itself is ever sent to anyone but the Puppet Master.

TODO(post-MVP): more sabotage verbs, elimination limitations (cooldowns,
proximity, requiring a clue first), camera feed "offline" overlay when
the target room's security camera has been destroyed.

## Mystery controls (the core social mechanic)

- A **control** (light switch, water valve) in one player's room is
  secretly wired to an **effect** (a light, a broken pipe) in a
  *different* player's room, via `LinkGraph`.
- Controls/effects are grouped into **channels** ("light", "flood") - a
  control only ever links within its own channel, so a light switch
  never accidentally controls a broken pipe.
- **Guaranteed no self-links**: within each channel, `LinkGraph` orders
  rooms randomly and then rotates the pairing by one position - a real
  derangement, not just "usually shuffled away from itself" - so **no
  control ever links to an effect in its own room**, full stop. This is
  what makes the Puppet Master's "never affects his own room" rule an
  actual guarantee rather than a probability.
- The **activator** gets only ambiguous **local feedback** (a tick/buzz) -
  they know *something* happened, never what or to whom.
- The **affected player** gets a clear **local event** at their own prop -
  they feel it directly, but never learn who caused it.
- The server is the only place that ever holds the full control->effect
  graph; it is never sent to any client.

TODO(post-MVP): more control/effect types beyond light+flood+gas, multi-hop
chains, per-round reshuffles.

## Room utilities

Each room exposes four manipulable utility states via `RoomUtilities.gd`
(replicated to every peer for local feedback):

- **Power** — room lights only turn on when power is enabled.
- **Water** — flood effects (`BrokenPipe`) only apply when water utility
  is on.
- **Gas** — stub channel; gas-valve controls can disable gas in a linked
  room (local toast only for now).
- **Communication** — phones refuse to send when comms are off in the
  sender's room.

An optional **electrical box** puzzle (3 broken wires + live wire) lets a
player route power to one of three other rooms. Host resolves wire targets
at spawn time and bakes them into replicated room data.

## Flooding

- Every room gets a `BrokenPipe` effect prop (like every room gets a
  `RoomLight`), but most sit inert unless some OTHER room's `WaterValve`
  happens to be linked to them (per-room valve odds are host-configurable
  - see "Host spawn odds").
- Each valve activation **slowly trickles** water into the target room
  over time (`BrokenPipe.TRICKLE_RATE`, host-authoritative) rather than
  jumping instantly — a rising semi-transparent water plane, capped so it
  never clips the ceiling. Level is cached into
  `GameState.room_water_levels[room_index]` on every peer.
- **Gameplay effect**: a player physically standing in a flooded room
  moves proportionally slower (`Player.gd`, up to 60% slower at max
  flood), and a room flooded past `EscapeSystem.FLOOD_BLOCK_LEVEL` has
  its escape physically blocked ("the water's too high").
- This is a stub - water level only ever rises (no drainage) and there's
  a single flood tier scale, not a real fluid simulation.

## Comms

- **Phones**: unknown/random lines. The *caller does not pick a
  recipient* - the server randomly routes to another living,
  non-escaped, non-eliminated player. **Text first** (implemented).
- Every peer has an opaque, per-match **line id** (e.g. "Line 07") that
  tags their outgoing texts instead of a generic "Unknown Line" literal -
  still anonymous, but now distinguishable across multiple calls.
- Players can **locally rename a line** ("I think Line 07 is Sam") via
  `ContactBook` - a client-only, unsynced nickname map, persisted to a
  small local config file. Two players can give the same line completely
  different (or wrong!) nicknames; nobody else ever sees your renames.
  The redesigned phone panel lists every known line as a clickable
  button (mouse click, OR keyboard/gamepad focus + confirm both work) -
  pressing one opens an inline rename field.
- **PA, windows, writing/notes**: not implemented yet. They're expected
  to reuse `PhoneSystem`'s routing core (random recipient, no
  caller-side targeting) once built.
- Opening the phone (or the code keypad) **locks player input** - no
  movement, no look, no jump - until it's closed.

## Puzzles

- Some room escapes are **code-locked** (`PuzzleSystem`), gated by
  host-configurable odds (see "Host spawn odds"). Interacting with a
  locked escape gives clear local feedback ("It's locked, find the
  code") rather than silently failing.
- Entering a code uses a **physical keypad**: individual digit buttons
  (0-9, clear, backspace) the player presses one at a time, building up
  a display, then Submit - so a teammate on the phone can dictate a code
  digit by digit, same as a real keypad. No typing on a text field.
- The code is **never sent to the locked room's keypad** - only the
  server knows it. It's discoverable as a readable clue placed in a
  DIFFERENT player's room (mirroring LinkGraph's "the answer lives
  somewhere else" theming), with clue-type odds also host-configurable:
  - A **book** (`ClueBook`), always readable on interact.
  - A **grabbable flame-lit paper** (`ClueFlamePaper`): interacting picks
    it up (host-authoritative); the player then has to physically carry
    it near a `Flame` prop. Close enough for a moment and the code
    **appears on the paper** (a client-side proximity/timer check - the
    text isn't secret at the netcode level, same as the book). Get **too
    close** for too long, though, and the paper **catches fire and is
    destroyed** - reusing the shared `Interactable` destroy mixin - and
    the clue is lost for good.
- MVP wires this up to gate **escape** only. The same
  `server_register_lock` / `request_attempt_unlock` core could gate a
  camera or other feature too - not built yet.
- At most one room is locked per match (skipped entirely if there
  aren't enough rooms to make it interesting, e.g. solo testing, or if
  the host's "code lock" odds roll doesn't hit).

## Movable & destroyable props

- **Movable** (`MovableProp`): some props (currently a bookcase blocking
  a hidden hallway/vent opening) can be pushed aside - a
  host-authoritative position tween replicated to everyone, with
  collision disabled once moved so the newly-revealed path is actually
  walkable.
- **Destroyable** (shared mixin on the `Interactable` base class): some
  props (each room's phone, security camera, and the grabbable flame
  paper's "burn" case) can be destroyed. Destroying requires **holding**
  the `destroy` input (default `F`) for about a second - a HUD progress
  bar shows the hold - rather than a single tap, so it can't happen by
  accident. Destroying just hides the prop and disables its collision/
  behavior - a destroyed phone can no longer receive calls; a destroyed
  camera is visibly gone to anyone who walks by.
- **The security camera specifically requires elevation** to destroy: it's
  mounted near the ceiling, and `SecurityCamera.min_elevation_y` (checked
  before the destroy-hold is even allowed to start) means a player has
  to actually climb the room's `Ladder` first - see below - rather than
  destroying it from the floor.

## Ladders & climbing

- `Ladder.gd` is an `Area3D` "climb zone" placed next to each room's
  security camera. While a player's body is inside it, `Player.gd`
  switches to climbing physics: forward/back input moves vertically
  (`CLIMB_SPEED`), gravity is suspended, and normal ground movement
  resumes immediately on leaving the zone. Ladders are also **grabbable**:
  pick up with `E`, carry, and place against the nearest wall (raycast-
  snapped, stays vertical). This is what actually lets a player reach the
  elevated security camera to destroy it.

## Debug GUI (*** REMOVE OR GATE BEFORE RELEASE ***)

Toggle with the **Home** key. Host gets buttons to spawn a test gun,
toggle utilities in the current room, and reset spawn odds. Clients see
a read-only panel. See `scripts/debug_gui.gd`.

## Test-only tools (*** REMOVE BEFORE FULL RELEASE ***)

- A pickup **Gun** (`Gun.gd`) and a few **DummyTarget** props live in the
  Outside courtyard, under a node explicitly named
  `TestRange_RemoveBeforeRelease`. Picking up the gun and left-clicking
  fires a **visible projectile** (`TestProjectile.gd`, host-authoritative
  collision); hitting a dummy flashes it red and wobbles it (purely
  cosmetic feedback). This exists **solely** to manually verify
  hit-registration during development. **Remove `Gun.gd`, `DummyTarget.gd`,
  `TestProjectile.gd`, `debug_gui.gd`, the `fire` input action,
  `Player.has_gun`/`_fire_gun()`, and the test nodes before shipping.**

## Host spawn odds

- The host's Play screen exposes sliders (applied at match generation,
  host-authoritative, never synced to clients - see `MatchSettings.gd`)
  for:
  - **Hidden hallway** chance (a rolled hallway connector being blocked
    by a secret bookcase).
  - **Code lock** chance (this match having a code-locked escape at
    all).
  - **Flame paper** chance (a placed clue being the grabbable flame
    paper instead of a book).
  - **Flood valve** chance (each individual room getting a water valve).
- **Clients** see a read-only notice; sliders are disabled on join.
- These are read ONLY by `Match._server_build_match()`/`RoomPod.plan_recipe()`
  during generation. **Important implementation note**: `RoomPod.configure()`
  itself (which runs identically on every peer to build the replicated
  room) must NEVER read `MatchSettings` directly, since that's a
  per-peer local autoload - a client's own (default) odds could silently
  differ from the host's and desync the visual room layout. Every
  odds-gated decision is resolved ONCE, server-side, by
  `RoomPod.plan_recipe()` and baked into the replicated spawn data
  instead - this was a real bug caught during testing, not just a
  theoretical concern.

## Escape & win condition

- A room's **escape point** (door or vent) is a direct, unambiguous
  action (not a mystery prop) - reach it, interact, you're marked
  escaped and moved to the shared **Outside** courtyard. May be
  code-locked (see "Puzzles") or physically blocked by flooding (see
  "Flooding").
- **Outside** is shared by every escaped player regardless of faction.
  No post-escape sabotage or interaction in MVP - it's just a holding
  area until the match ends.
- **Win condition**: the first faction with **ALL** of its members
  escaped wins immediately (`GameState.server_check_for_win`,
  `EscapeSystem._check_for_win`). Escaping is necessary but not
  sufficient for your faction to win - your whole team has to make it
  out. See "Puppet Master" above for how that role's win condition
  interacts with this one.

## Networking

- **Host-authoritative** Godot 4 `MultiplayerAPI` over `ENetMultiplayerPeer`.
- Host/join is a direct-IP shell for MVP (`NetworkManager.host_game` /
  `join_game`). **No lobby codes, no NAT traversal/relay yet** - that's
  explicitly future work.
- Every trust-sensitive RPC (faction assignment, mystery-link resolution,
  escape approval, phone routing, puzzle attempts, Puppet Master actions)
  lives on an autoload singleton (`NetworkManager`, `LinkGraph`,
  `PhoneSystem`, `EscapeSystem`, `PuzzleSystem`, `PuppetMasterSystem`),
  which default to multiplayer authority `1` (the server) - so
  `@rpc("authority", ...)` methods on them are "only the host may call
  this" for free, no extra wiring needed.
- Rooms and players are spawned via `MultiplayerSpawner.spawn(data)`
  with a custom `spawn_function`, the standard Godot 4 pattern for
  deterministic host-authoritative spawning that replicates consistently
  to every client. Every room's full recipe (size/theme/escape/connector/
  puzzle/valve/Puppet-Master-or-not) travels inside that one `data`
  dictionary so the same room is built identically everywhere - see the
  "Host spawn odds" note above for why that matters more than it sounds.

## Explicitly OUT of scope for this scaffold (do not claim these work)

- Voice comms.
- Lobby codes / matchmaking / relay (NAT traversal).
- Fully hand-authored/varied room shapes (today: box-and-gap procedural
  construction from a recipe, not literal mesh-based level generation).
- Post-escape interactions/sabotage from Outside.
- More than one sabotage verb for the Puppet Master; more control/effect
  channels beyond light+flood.
- PA, windows, and note comms (stubs only, not built).
- Puzzle gating for anything other than escape (camera/feature gating is
  architecturally possible, not wired up).
- Camera feed "destroyed camera" offline overlay (destruction itself
  works and is visible in-world; the PM's feed UI doesn't yet reflect it).
- Real fluid simulation for flooding (a single rising water plane + a
  flat speed/escape penalty, no drainage).
- Crouching (the vent connector module is walkable at normal height for
  scope reasons, not a true crawlspace - see `RoomPod` class doc).
- Anti-cheat / server-side movement validation.
- Settings/Character screens beyond what's listed above (Character is
  still a stub panel).
- The test-only Gun/DummyTarget tools (explicitly marked for removal
  before release - see "Test-only tools" above).
- Any real art pass - everything is graybox on purpose.
