<p align="center">
  <img src="docs/brand/vouch-lockup-480.png" alt="Vouch" width="420" />
</p>

# Vouch

A Godot 4 multiplayer social-deduction game set in an industrial bunker.
Players wake up alone, split into rival factions - plus one secret
**Puppet Master** who isn't on anyone's side. Nobody knows who's on their
team. Interacting with the bunker's mystery controls affects *someone
else*, somewhere - you'll never know who. Escape with your whole faction
to win... unless the Puppet Master gets to everyone first.

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
3. Press **F5** (Run Project) - it opens on the **Home** screen.

## Trying it out locally (host + join on one machine)

The fastest way to see the multiplayer loop end-to-end without a second
machine:

1. Run the project once (F5). From the Home screen, click **Play**, then
   **Host Match**.
2. Run the project **again** in a second editor instance (Godot lets you
   run multiple instances of the same project - use
   **Debug > Run Multiple Instances** in newer editor builds, or just
   launch the exported/debug binary a second time from a terminal:
   `godot4 --path . `).
3. In the second instance, **Play -> Join** with the IP field left blank
   (defaults to `127.0.0.1`).
4. Back in the **first** (host) instance, watch the joined-player list
   below the host/join controls fill in, then click **Start Match**.
5. Both instances load into the Match scene. Each player spawns alone in
   their own procedurally-built room (size/theme/layout/escape all vary -
   see the controls table and docs/MVP_GDD.md for details).

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
| Interact (phone, switch, escape, keypad, clues, movable props) | `E` |
| Destroy (marked props only - phone, security camera) | `F` |
| Release/recapture mouse, close an open panel | `Esc` |

Any open modal panel (phone or code keypad) fully locks movement/look/
jump until it's closed - typing a text or a code never accidentally
moves or jumps your character.

## What's implemented (stub-quality, but functional)

- **Home screen**: Play / Settings / Character / Exit
  (`scripts/lobby.gd`). Settings and Character are stub panels for now.
- **Host/join shell** over Godot's high-level `MultiplayerAPI`
  (`ENetMultiplayerPeer`), host-authoritative
  (`scripts/autoload/network_manager.gd`), with a **live joined-player
  list** visible to everyone before the match starts.
- **Home -> Match** flow: host starts the match, every connected player
  gets spawned into their own procedurally-built room - varied size,
  visual theme (Bedroom / Utility Room / Creepy Basement), optional
  closet/hidden-hallway layout feature, decorative pipes/wires, and
  either a door or a vent/shaft escape (`scripts/match.gd`,
  `scripts/room_pod.gd`).
- **Faction assignment** on match start, round-robin across the 4 MVP
  factions (Red Vipers / Blue Ash / Green Hollow / Yellow Sparks). Each
  client is told **only its own faction** via a targeted RPC - there is
  no teammate-list UI anywhere, by design.
- **Puppet Master**: exactly one player's room has no escape at all.
  They get camera feeds (real `SubViewport` renders) + a sabotage button
  into a few other rooms, and can eliminate any other player
  (`scripts/systems/puppet_master_system.gd`). They win if everyone else
  is eliminated before any faction fully escapes - otherwise the first
  fully-escaped faction wins as normal. See docs/MVP_GDD.md for the full
  win/lose rule.
- **Mystery control -> effect link** (`scripts/systems/link_graph.gd`):
  flipping a light switch in your room secretly affects a light in
  *someone else's* room. You get ambiguous local feedback (a "tick"),
  they get a clear local event - neither of you learns who's connected
  to whom.
- **Code-lock puzzles** (`scripts/systems/puzzle_system.gd`): a room's
  escape may require a 4-digit code, discoverable as a book or a
  flame-lit paper (only readable near the flame) hidden in a *different*
  room.
- **Movable & destroyable props**: a bookcase can be pushed aside to
  reveal a hidden hallway; each room's phone and security camera can be
  destroyed with `F` (host-authoritative, replicated).
- **Phone stub** (`scripts/systems/phone_system.gd`): unknown/random
  line, text-first, tagged with an anonymous per-match "line id" instead
  of a peer identity. You can **locally rename a line** if you think you
  know who it is (`scripts/autoload/contact_book.gd`) - purely a personal
  memory aid, never synced to anyone else.
- **Escape + win-check** (`scripts/systems/escape_system.gd`): reach your
  room's escape point, interact, and you're moved to the shared Outside
  courtyard. The first faction with **all** members escaped wins - logged
  to console (`[EscapeSystem] MATCH OVER - ...`).
- **Player movement stub**: first-person `CharacterBody3D` with
  authority-gated input and replicated transform via
  `MultiplayerSynchronizer`.

## What's explicitly NOT implemented (don't assume otherwise)

- **Voice comms.** Only text-first phone stub exists.
- **Lobby codes / matchmaking / relay.** Direct IP only - no NAT
  traversal, no session codes.
- **Fully hand-authored/varied room shapes.** Rooms are procedurally
  built from a recipe (size/theme/layout/escape), not a literal
  mesh-based level generator.
- **Post-escape interactions from Outside.** It's a neutral holding area
  with no sabotage/mechanics in MVP.
- **PA announcements and window/note comms.** Called out in the design
  doc as planned, not built - only the phone stub exists so far.
- **More than one control/effect type in `LinkGraph`**, and only one
  sabotage verb for the Puppet Master (toggling a room's light).
- **Puzzle gating for anything besides escape.** The core is reusable for
  camera/feature gating, but only escape is wired up.
- **Settings / Character screens.** Stub panels only, no functionality.
- **Anti-cheat / server-side movement validation.**
- **Real art.** Everything is graybox on purpose.

Every stub above has a `TODO(post-MVP)` comment at its definition site
pointing at what's missing.

## Project structure

```
project.godot              Godot 4 project config (autoloads, input map, etc.)
scenes/
  Main.tscn                 Actual main scene: composes Lobby (Home) + World (Match+Outside)
  Lobby/Lobby.tscn           Home screen: Play/Settings/Character/Exit + joined-player list
  Match/Match.tscn           Match director (spawns rooms + players)
  Match/RoomPod.tscn         Empty shell - RoomPod.gd builds the whole room procedurally
  Match/Props/               Small graybox decoration scenes (crate/shelf/barrel)
  Outside/Outside.tscn       Shared post-escape courtyard
  Player/Player.tscn         First-person player pawn + HUD (phone/keypad/camera/eliminated panels)
scripts/
  main.gd, match.gd, outside.gd, lobby.gd, player.gd, room_pod.gd
  autoload/                  GameState, FactionData, NetworkManager, ContactBook
  systems/                   LinkGraph, PhoneSystem, EscapeSystem, PuzzleSystem, PuppetMasterSystem
  interactables/              Interactable base (+ destroy mixin) and every prop type:
                              LightSwitch, Door (door/vent), Phone, RoomLight, SecurityCamera,
                              CodeKeypad, ClueBook, ClueFlamePaper, Flame, MovableProp
assets/
  materials/                  Shared graybox materials + default environment
  brand/                       Small in-engine copy of the Vouch icon
docs/
  MVP_GDD.md                  Design locks / what's in vs. out of MVP
  brand/                       Reference copies of the Vouch logo/lockup
```

## Autoloads (singletons)

Registered in `project.godot` under `[autoload]`:

- **GameState** - match-wide state (phase, per-player faction/room/escape/
  elimination status, Puppet Master identity). Full roster is
  server-only; clients only ever know their own faction/role.
- **FactionData** - static faction definitions (id/name/color) and the
  active-faction-count knob for N-faction support later.
- **NetworkManager** - host/join bootstrap, peer connect/disconnect
  handling, faction-assignment + lobby-roster broadcast, match-start
  signal.
- **ContactBook** - client-local, unsynced phone line nickname map.
- **LinkGraph** - mystery control/effect registry and resolution.
- **PhoneSystem** - random-recipient text routing + per-match line ids.
- **EscapeSystem** - escape handling + faction win-check.
- **PuzzleSystem** - code-lock registry and unlock attempts.
- **PuppetMasterSystem** - Puppet Master assignment, camera/sabotage
  grants, elimination, and PM win-check.

## License

No license file yet - add one before treating this as anything other
than a personal/team scaffold.
