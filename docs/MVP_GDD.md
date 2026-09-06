# Vouch - MVP Game Design Document

Concise reference for the design decisions this scaffold was built around.
If code and this doc ever disagree, this doc wins for *intent* - file a
TODO and fix the code.

## One-line pitch

8 players wake up alone in an industrial bunker, split into 4 rival
factions. Nobody knows who's on their team. Escape together, or don't.

## Setting

Industrial bunker / underground facility. Cold, functional, no frills -
graybox rooms, exposed fixtures, one working light per room, a phone,
a door.

## Factions

- MVP: **4 factions, 2 players each** (4v4 flavor, 8 players total).
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

- Each player spawns **alone** in their own small room ("RoomPod").
- MVP ships **one room template** reused for every player, with
  **procedurally randomized prop placement** (deterministic per-room
  seed) - this satisfies "randomly generated room with procedural props"
  without yet building out multiple room shapes/layouts. See
  `RoomPod.gd` / `scenes/Match/RoomPod.tscn`.
- TODO(post-MVP): multiple room shapes, randomized wall openings, richer
  prop variety, hand-authored art pass.

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
  non-escaped player. **Text first** (implemented). Voice is explicitly
  future work.
- **PA, windows, writing/notes**: not implemented yet. They're expected
  to reuse `PhoneSystem`'s routing core (random recipient, no
  caller-side targeting) once built.

## Escape & win condition

- A room's **Door** is a direct, unambiguous escape action (not a
  mystery prop) - reach it, interact, you're marked escaped and moved to
  the shared **Outside** courtyard.
- **Outside** is shared by every escaped player regardless of faction.
  No post-escape sabotage or interaction in MVP - it's just a holding
  area until the match ends.
- **Win condition**: the first faction with **ALL** of its members
  escaped wins immediately (`GameState.server_check_for_win`,
  `EscapeSystem._check_for_win`). Escaping is necessary but not
  sufficient for your faction to win - your whole team has to make it
  out.

## Networking

- **Host-authoritative** Godot 4 `MultiplayerAPI` over `ENetMultiplayerPeer`.
- Host/join is a direct-IP shell for MVP (`NetworkManager.host_game` /
  `join_game`). **No lobby codes, no NAT traversal/relay yet** - that's
  explicitly future work.
- Every trust-sensitive RPC (faction assignment, mystery-link resolution,
  escape approval, phone routing) lives on an autoload singleton
  (`NetworkManager`, `LinkGraph`, `PhoneSystem`, `EscapeSystem`), which
  default to multiplayer authority `1` (the server) - so `@rpc("authority", ...)`
  methods on them are "only the host may call this" for free, no extra
  wiring needed.
- Rooms and players are spawned via `MultiplayerSpawner.spawn(data)`
  with a custom `spawn_function`, the standard Godot 4 pattern for
  deterministic host-authoritative spawning that replicates consistently
  to every client.

## Explicitly OUT of scope for this scaffold (do not claim these work)

- Voice comms.
- Lobby codes / matchmaking / relay (NAT traversal).
- Full procedural level generation (today: one room template + randomized
  props).
- Post-escape interactions/sabotage from Outside.
- More than one control/effect type in LinkGraph.
- PA, windows, and note comms (stubs only, not built).
- Anti-cheat / server-side movement validation.
- Any real art pass - everything is graybox on purpose.
