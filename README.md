<p align="center">
  <img src="docs/brand/vouch-lockup-480.png" alt="Vouch" width="420" />
</p>

# Vouch

A Godot 4 multiplayer social-deduction game set in an industrial bunker.
Eight players wake up alone, split into four rival factions. Nobody knows
who's on their team. Interacting with the bunker's mystery controls
affects *someone else*, somewhere - you'll never know who. Escape with
your whole faction to win.

This repository is a **scaffold**: graybox rooms, stub systems, and a lot
of clearly-marked `TODO(post-MVP)` comments. See
[`docs/MVP_GDD.md`](docs/MVP_GDD.md) for the full design reference and
exactly what is/isn't implemented yet.

## Requirements

- **Godot 4.3+** (developed against 4.3-stable; any 4.3.x/4.4.x should
  work). Get it from [godotengine.org](https://godotengine.org/download).
- No paid assets, plugins, or export templates needed to run/edit the
  project - everything is graybox primitives and built-in nodes.

## Opening the project

1. Launch Godot 4, click **Import**, and select this repository's
   `project.godot`.
2. Open the project. Godot will import assets on first load (a few
   seconds).
3. Press **F5** (Run Project) - it opens on the **Lobby** scene.

## Trying it out locally (host + join on one machine)

The fastest way to see the multiplayer loop end-to-end without a second
machine:

1. Run the project once (F5). In the Lobby, click **Host Match**.
2. Run the project **again** in a second editor instance (Godot lets you
   run multiple instances of the same project - use
   **Debug > Run Multiple Instances** in newer editor builds, or just
   launch the exported/debug binary a second time from a terminal:
   `godot4 --path . `).
3. In the second instance's Lobby, leave the IP field blank (defaults to
   `127.0.0.1`) and click **Join**.
4. Back in the **first** (host) instance, click **Start Match** once you
   see "Players connected: 2".
5. Both instances load into the Match scene. Each player spawns alone in
   their own randomly-propped room. Move with `WASD`, look with the
   mouse, `Space` to jump, `E` to interact, `Esc` to release the mouse
   cursor (press again to recapture).

To test across two real machines on the same network instead: host on
one machine, then on the other type the host's LAN IP into the Join
field. There's no lobby-code/relay system yet (see below), so direct IP
is required for now.

## Controls

| Action | Key |
| --- | --- |
| Move | `W A S D` |
| Look | Mouse |
| Jump | `Space` |
| Interact | `E` |
| Release/recapture mouse, close phone panel | `Esc` |

## What's implemented (stub-quality, but functional)

- **Host/join shell** over Godot's high-level `MultiplayerAPI`
  (`ENetMultiplayerPeer`), host-authoritative. See
  `scripts/autoload/network_manager.gd`.
- **Lobby -> Match** flow: host starts the match, every connected player
  gets spawned into their own procedurally-propped room
  (`scripts/match.gd`, `scenes/Match/RoomPod.tscn`).
- **Faction assignment** on match start, round-robin across the 4 MVP
  factions (Red Vipers / Blue Ash / Green Hollow / Yellow Sparks). Each
  client is told **only its own faction** via a targeted RPC - there is
  no teammate-list UI anywhere, by design.
- **Mystery control -> effect link** (`scripts/systems/link_graph.gd`):
  flipping a light switch in your room secretly affects a light in
  *someone else's* room. You get ambiguous local feedback (a "tick"),
  they get a clear local event - neither of you learns who's connected
  to whom.
- **Phone stub** (`scripts/systems/phone_system.gd`): unknown/random
  line, text-first. You can't pick who you're calling; the server picks
  a random other living player to deliver your text to.
- **Escape + faction win-check** (`scripts/systems/escape_system.gd`):
  reach your room's door, interact, and you're moved to the shared
  Outside courtyard. The first faction with **all** members escaped
  wins - logged to console (`[EscapeSystem] MATCH OVER - ...`).
- **Player movement stub**: first-person `CharacterBody3D` with
  authority-gated input and replicated transform via
  `MultiplayerSynchronizer`.

## What's explicitly NOT implemented (don't assume otherwise)

- **Voice comms.** Only text-first phone stub exists.
- **Lobby codes / matchmaking / relay.** Direct IP only - no NAT
  traversal, no session codes.
- **Full procedural level generation.** MVP reuses one room template
  with randomized prop placement, not varied room layouts.
- **Post-escape interactions from Outside.** It's a neutral holding area
  with no sabotage/mechanics in MVP.
- **PA announcements and window/note comms.** Called out in the design
  doc as planned, not built - only the phone stub exists so far.
- **More than one control/effect type in `LinkGraph`.** Light switch ->
  room light is the only wired pair today.
- **Anti-cheat / server-side movement validation.**
- **Real art.** Everything is graybox on purpose.

Every stub above has a `TODO(post-MVP)` comment at its definition site
pointing at what's missing.

## Project structure

```
project.godot              Godot 4 project config (autoloads, input map, etc.)
scenes/
  Main.tscn                 Actual main scene: composes Lobby + World (Match+Outside)
  Lobby/Lobby.tscn           Host/join UI stub
  Match/Match.tscn           Match director (spawns rooms + players)
  Match/RoomPod.tscn         One player's room (light switch, door, phone, room light)
  Match/Props/               Small graybox decoration scenes (crate/shelf/barrel)
  Outside/Outside.tscn       Shared post-escape courtyard
  Player/Player.tscn         First-person player pawn + HUD
scripts/
  main.gd, match.gd, outside.gd, lobby.gd, player.gd, room_pod.gd
  autoload/                  GameState, FactionData, NetworkManager
  systems/                   LinkGraph, PhoneSystem, EscapeSystem
  interactables/              Interactable base + LightSwitch/Door/Phone/RoomLight
assets/
  materials/                  Shared graybox materials + default environment
  brand/                       Small in-engine copy of the Vouch icon
docs/
  MVP_GDD.md                  Design locks / what's in vs. out of MVP
  brand/                       Reference copies of the Vouch logo/lockup
```

## Autoloads (singletons)

Registered in `project.godot` under `[autoload]`:

- **GameState** - match-wide state (phase, per-player faction/room/escape
  status). Full roster is server-only; clients only ever know their own
  faction.
- **FactionData** - static faction definitions (id/name/color) and the
  active-faction-count knob for N-faction support later.
- **NetworkManager** - host/join bootstrap, peer connect/disconnect
  handling, faction-assignment broadcast, match-start signal.
- **LinkGraph** - mystery control/effect registry and resolution.
- **PhoneSystem** - random-recipient text routing.
- **EscapeSystem** - escape handling + faction win-check.

## License

No license file yet - add one before treating this as anything other
than a personal/team scaffold.
