# Vouch - MVP Game Design Document

Concise reference for the design decisions this scaffold was built around.
If code and this doc ever disagree, this doc wins for *intent* - file a
TODO and fix the code.

## One-line pitch

8 players wake up alone in an industrial bunker, split into 4 rival
factions - plus one secret **Puppet Master** who isn't on anyone's side.
Nobody knows who's on their team. Escape together, or don't. One of you
might be trying to make sure nobody does.

## Setting

Industrial bunker / underground facility. Cold, functional, no frills -
graybox rooms, exposed fixtures, pipes and wires, one working light per
room, a phone, an escape point, a security camera.

## Home screen

- Landing screen ("Home") offers **Play / Settings / Character / Exit**.
  Settings and Character are stub panels for now (see `Lobby.gd`) -
  no functionality behind them yet beyond a placeholder message.
- **Play** opens the existing host/join flow. A live **joined-player
  list** (name + peer id) is shown below the host/join controls and
  updates as peers connect/disconnect (`NetworkManager.lobby_roster_updated`,
  broadcast to everyone). This is pre-match "who's here" information
  only - no faction/role data, consistent with the privacy rule below.

## Factions

- MVP: **4 factions, 2 players each** (4v4 flavor) plus **1 Puppet
  Master**, for 9 players total when the Puppet Master is in play (8
  without). See "Puppet Master" below.
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

## Rooms

Each player spawns **alone** in their own procedurally-built room
("RoomPod" - see `scripts/room_pod.gd`). Every room is built entirely in
code from a small "recipe" chosen deterministically from a per-room seed,
so it replicates identically to every client without sending mesh data
over the network:

- **Size varies**: 3 size tiers (Compact/Standard/Spacious).
- **Theme varies**: 3 themes with distinct color palettes - **Bedroom**,
  **Utility Room**, **Creepy Basement** - obvious at a glance.
- **Layout varies**: each room may roll a **closet** alcove, a
  **hallway leading to a second chamber**, decorative **pipes**, and/or
  decorative **electrical wires**. A hidden hallway may be blocked by a
  **movable bookcase** (see "Movable & destroyable props").
- **Escape varies**: most rooms escape through a **door**; some use a
  **vent/shaft** instead. Functionally identical (same `Door.gd` script,
  different prompt/visual), so it's purely a flavor read for players.
- **Exactly one room has no escape at all** - that player is the
  **Puppet Master** (see below).

TODO(post-MVP): hand-authored room shapes instead of box-and-gap
construction, more themes, richer decoration variety.

## Puppet Master

- A **fifth, independent role**, not part of any rival faction. Their
  room has **no escape**.
- **Goal**: eliminate every other player before any faction fully
  escapes.
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

- A **control** (light switch, eventually valves/breakers/etc.) in one
  player's room is secretly wired to an **effect** (a light, eventually
  doors/alarms/etc.) in a *different* player's room.
- The **activator** gets only ambiguous **local feedback** (a tick/buzz) -
  they know *something* happened, never what or to whom.
- The **affected player** gets a clear **local event** at their own prop -
  they feel it directly, but never learn who caused it.
- The server is the only place that ever holds the full control->effect
  graph (`LinkGraph`); it is never sent to any client.
- MVP ships exactly one control type (light switch) and one effect type
  (room light), linked 1:1 for the whole match. TODO(post-MVP): more
  control/effect types, multi-hop chains, per-round reshuffles.

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
- **PA, windows, writing/notes**: not implemented yet. They're expected
  to reuse `PhoneSystem`'s routing core (random recipient, no
  caller-side targeting) once built.
- Opening the phone (or any modal panel) **locks player input** - no
  movement, no look, no jump - until it's closed.

## Puzzles

- Some interactables are **code-locked** (`PuzzleSystem`): a room's
  escape point can require a 4-digit code before it'll let you through.
  Interacting with it while locked gives clear local feedback ("It's
  locked, find the code") rather than silently failing.
- The code is **never sent to the locked room's keypad** - only the
  server knows it. It's discoverable as a readable clue placed in a
  DIFFERENT player's room (mirroring LinkGraph's "the answer lives
  somewhere else" theming):
  - A **book** (`ClueBook`), always readable, or
  - A **flame-lit paper** (`ClueFlamePaper`), only readable while
    standing near a paired `Flame` prop (a client-side distance check -
    the text itself isn't secret at the netcode level, it's just
    narratively "too dark to read" otherwise).
- MVP wires this up to gate **escape** only. The same
  `server_register_lock` / `request_attempt_unlock` core could gate a
  camera or other feature too - not built yet.
- At most one room is locked per match (skipped entirely if there
  aren't enough rooms to make it interesting, e.g. solo testing).

## Movable & destroyable props

- **Movable** (`MovableProp`): some props (currently a bookcase blocking
  a hidden hallway opening) can be pushed aside - a host-authoritative
  position tween replicated to everyone, with collision disabled once
  moved so the newly-revealed path is actually walkable.
- **Destroyable** (shared mixin on the `Interactable` base class): some
  props (each room's phone and security camera) can be destroyed with a
  separate `destroy` input (default `F`), host-authoritative. Destroying
  a prop just hides it and disables its collision/behavior - a phone that's
  been destroyed can no longer receive calls; a destroyed camera is
  visibly gone to anyone who walks by.

## Escape & win condition

- A room's **escape point** (door or vent) is a direct, unambiguous
  action (not a mystery prop) - reach it, interact, you're marked
  escaped and moved to the shared **Outside** courtyard. May be
  code-locked (see "Puzzles").
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
  to every client. Every room's full recipe (size/theme/escape/puzzle/
  Puppet-Master-or-not) travels inside that one `data` dictionary so the
  same room is built identically everywhere.

## Explicitly OUT of scope for this scaffold (do not claim these work)

- Voice comms.
- Lobby codes / matchmaking / relay (NAT traversal).
- Fully hand-authored/varied room shapes (today: box-and-gap procedural
  construction from a recipe, not literal mesh-based level generation).
- Post-escape interactions/sabotage from Outside.
- More than one control/effect type in LinkGraph; more than one
  sabotage verb for the Puppet Master.
- PA, windows, and note comms (stubs only, not built).
- Puzzle gating for anything other than escape (camera/feature gating is
  architecturally possible, not wired up).
- Camera feed "destroyed camera" offline overlay (destruction itself
  works and is visible in-world; the PM's feed UI doesn't yet reflect it).
- Anti-cheat / server-side movement validation.
- Settings/Character screens (stub panels only).
- Any real art pass - everything is graybox on purpose.
