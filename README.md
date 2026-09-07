<p align="center">
  <img src="docs/brand/vouch-lockup-480.png" alt="Vouch" width="420" />
</p>

# Vouch

A Godot 4 multiplayer social-deduction game set in an industrial bunker.
Players wake up alone, split into rival factions - plus, some games, one
secret **Puppet Master** who isn't on anyone's side. Nobody knows who's on
their team. Interacting with the bunker's mystery controls affects
*someone else*, somewhere - you'll never know who. Escape with your whole
faction to win... unless the Puppet Master gets to everyone first.

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
   **Host Match**. Optionally adjust the "Match spawn odds" sliders that
   appear (code locks, flame paper, flood valves, hidden hallways).
2. Run the project **again** in a second editor instance (Godot lets you
   run multiple instances of the same project - use
   **Debug > Run Multiple Instances** in newer editor builds, or just
   launch the exported/debug binary a second time from a terminal:
   `godot4 --path . `).
3. In the second instance, **Play -> Join** with the IP field left blank
   (defaults to `127.0.0.1`).
4. Back in the **first** (host) instance, watch the joined-player list
   below the host/join controls fill in, then click **Start Match**. With
   4+ players there's a 50% chance one of you becomes the secret Puppet
   Master.
5. Both instances load into the Match scene. Each player spawns alone in
   their own procedurally-built room (size/theme/layout/escape all vary -
   see the controls table and docs/MVP_GDD.md for details).

To test across two real machines on the same network instead: host on
one machine, then on the other type the host's LAN IP into the Join
field. There's no lobby-code/relay system yet (see below), so direct IP
is required for now.

## Controls

| Action | Key (remappable in Settings) |
| --- | --- |
| Move | `W A S D` |
| Look | Mouse (sensitivity adjustable in Settings) |
| Jump | `Space` |
| Interact / pick up | `E` |
| Destroy (marked props only - **hold**, not tap) | `F` (hold ~1s) |
| Fire test gun (*** test-only, see below ***) | Left mouse button |
| Release/recapture mouse, close an open panel | `Esc` |

Any open modal panel (phone or code keypad) fully locks movement/look/
jump until it's closed - typing a text or a code never accidentally
moves or jumps your character. All bindings above except mouse-look and
`Esc` are remappable from **Home -> Settings**, which also has a mouse
sensitivity slider and master/SFX volume sliders (SFX is a stored-but-
inert stub - no sounds in the project yet). Everything in Settings
persists locally between sessions.

## What's implemented (stub-quality, but functional)

- **Home screen**: Play / Settings / Character / Exit (`scripts/lobby.gd`).
  Settings has real key remapping + mouse sensitivity + volume controls,
  all persisted locally (`scripts/autoload/settings_manager.gd`).
  Character is still a stub panel.
- **Host/join shell** over Godot's high-level `MultiplayerAPI`
  (`ENetMultiplayerPeer`), host-authoritative
  (`scripts/autoload/network_manager.gd`), with a **live joined-player
  list** visible to everyone before the match starts, and host-only
  **match spawn odds** sliders (`scripts/autoload/match_settings.gd`)
  for code locks / flame paper / flood valves / hidden hallways.
- **Modular procedural rooms**: every room is 1-2 chained modules (a
  Bedroom/Utility/Basement main room plus an optional Closet/Hallway/
  Vent connector), seamlessly joined with no gaps or void-peeking, with
  oversized pipes/wires so nothing shows a floating cut end
  (`scripts/room_pod.gd`).
- **Faction assignment** on match start, round-robin across the 4 MVP
  factions (Red Vipers / Blue Ash / Green Hollow / Yellow Sparks). Each
  client is told **only its own faction** via a targeted RPC - there is
  no teammate-list UI anywhere, by design.
- **Puppet Master**: only possible with 4+ players, and only a 50%
  chance even then. Their room is a perfect box with decorative
  monitors; no escape at all. They get camera feeds (real `SubViewport`
  renders) + a sabotage button into a few other rooms, and can eliminate
  any other player (`scripts/systems/puppet_master_system.gd`). Any
  control in their own room is guaranteed (not just likely) to never
  affect their own room - see `LinkGraph`. They win if everyone else is
  eliminated before any faction fully escapes - otherwise the first
  fully-escaped faction wins as normal.
- **Mystery controls** (`scripts/systems/link_graph.gd`): light switches
  and water valves secretly wired to a light or a broken pipe in
  *someone else's* room, with a mathematically guaranteed derangement -
  no control ever links back to its own room. You get ambiguous local
  feedback (a "tick"), they get a clear local event.
- **Flooding**: activate a linked water valve to raise water in a
  *different* room - slows movement for anyone standing in it and can
  physically block escape past a threshold.
- **Code-lock puzzles** with a **physical digit keypad** (press digits
  one at a time - a teammate can dictate a code over the phone). Codes
  are discoverable as a book or a **grabbable flame-lit paper**: carry it
  near a flame to reveal the code, but get too close for too long and it
  catches fire and is destroyed.
- **Movable & destroyable props**: a bookcase can be pushed aside to
  reveal a hidden hallway/vent; each room's phone and security camera
  can be destroyed by **holding** `F` (a HUD progress bar shows the
  hold), host-authoritative and replicated. The security camera is
  mounted near the ceiling and needs its room's **ladder** (real
  climbing physics) to reach.
- **Phone**, redesigned: unknown/random line, text-first, tagged with an
  anonymous per-match "line id". **Click any contact to rename it**
  locally (`scripts/autoload/contact_book.gd`) - a personal memory aid,
  never synced to anyone else; the rename flow works by mouse click or
  by keyboard/gamepad focus + confirm.
- **Escape + win-check** (`scripts/systems/escape_system.gd`): reach your
  room's escape point, interact, and you're moved to the shared Outside
  courtyard. The first faction with **all** members escaped wins - logged
  to console (`[EscapeSystem] MATCH OVER - ...`).
- **Player movement stub**: first-person `CharacterBody3D` with
  authority-gated input, ladder-climbing physics, and replicated
  transform via `MultiplayerSynchronizer`.
- **\*\*\* TEST-ONLY, REMOVE BEFORE FULL RELEASE \*\*\*** - a pickup gun
  and a few dummy targets in the Outside courtyard, purely to manually
  verify hit-registration during development. See "Test-only tools"
  below.

## What's explicitly NOT implemented (don't assume otherwise)

- **Voice comms.** Only text-first phone stub exists.
- **Lobby codes / matchmaking / relay.** Direct IP only - no NAT
  traversal, no session codes.
- **Fully hand-authored/varied room shapes.** Rooms are procedurally
  built from a recipe (size/theme/layout/escape/connector), not a
  literal mesh-based level generator. The "vent" connector module is
  walkable at normal height, not a true crawlspace (no crouching).
- **Post-escape interactions from Outside.** It's a neutral holding area
  with no sabotage/mechanics in MVP.
- **PA announcements and window/note comms.** Called out in the design
  doc as planned, not built - only the phone stub exists so far.
- **More than one sabotage verb for the Puppet Master**, and only two
  mystery-control channels (light, flood).
- **Puzzle gating for anything besides escape.** The core is reusable for
  camera/feature gating, but only escape is wired up.
- **Real fluid simulation for flooding.** A single rising water plane
  with a flat speed/escape penalty, no drainage.
- **Character screen.** Stub panel only, no functionality.
- **Anti-cheat / server-side movement validation.**
- **Real art.** Everything is graybox on purpose.

Every stub above has a `TODO(post-MVP)` comment at its definition site
pointing at what's missing.

## Test-only tools (*** REMOVE BEFORE FULL RELEASE ***)

The Outside courtyard has a `TestRange_RemoveBeforeRelease` node with a
pickup `Gun` and a few `DummyTarget` props, used solely to manually
verify multiplayer hit-registration during development - no ammo, no
damage model, no gameplay purpose. Before shipping, remove:
`scripts/interactables/gun.gd`, `scripts/interactables/dummy_target.gd`,
the `fire` input action in `project.godot`, the `has_gun`/`_fire_gun()`
bits in `scripts/player.gd`, and the `TestRange_RemoveBeforeRelease` node
from `scenes/Outside/Outside.tscn`.

## Project structure

```
project.godot              Godot 4 project config (autoloads, input map, etc.)
scenes/
  Main.tscn                 Actual main scene: composes Lobby (Home) + World (Match+Outside)
  Lobby/Lobby.tscn           Home screen: Play/Settings/Character/Exit, joined-player list,
                             match spawn odds, key remap + sensitivity + volume controls
  Match/Match.tscn           Match director (spawns rooms + players)
  Match/RoomPod.tscn         Empty shell - RoomPod.gd builds the whole modular room procedurally
  Match/Props/               Small graybox decoration scenes (crate/shelf/barrel)
  Match/Interactables/       Ladder.tscn (climbable zone + visual rungs)
  Outside/Outside.tscn       Shared post-escape courtyard + test-only gun/dummy range
  Player/Player.tscn         First-person player pawn + HUD (phone/keypad/camera/eliminated panels)
scripts/
  main.gd, match.gd, outside.gd, lobby.gd, player.gd, room_pod.gd
  autoload/                  GameState, FactionData, NetworkManager, ContactBook,
                             SettingsManager, MatchSettings
  systems/                   LinkGraph, PhoneSystem, EscapeSystem, PuzzleSystem, PuppetMasterSystem
  interactables/              Interactable base (+ destroy mixin) and every prop type:
                              LightSwitch, WaterValve, Door (door/vent), Phone, RoomLight,
                              BrokenPipe, SecurityCamera, Ladder, CodeKeypad, ClueBook,
                              ClueFlamePaper, Flame, MovableProp, Gun*, DummyTarget*
                              (* test-only, see above)
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
  elimination status, Puppet Master identity, room water levels). Full
  roster is server-only; clients only ever know their own faction/role.
- **FactionData** - static faction definitions (id/name/color) and the
  active-faction-count knob for N-faction support later.
- **NetworkManager** - host/join bootstrap, peer connect/disconnect
  handling, faction-assignment + lobby-roster broadcast, match-start
  signal.
- **ContactBook** - client-local, unsynced phone line nickname map.
- **SettingsManager** - client-local key remapping, mouse sensitivity,
  audio volume, persisted via `ConfigFile`.
- **MatchSettings** - host-authoritative match generation odds (code
  locks, flame paper, flood valves, hidden hallways).
- **LinkGraph** - mystery control/effect registry and guaranteed-no-
  self-link resolution.
- **PhoneSystem** - random-recipient text routing + per-match line ids.
- **EscapeSystem** - escape handling + faction win-check + flood-block
  check.
- **PuzzleSystem** - code-lock registry and unlock attempts.
- **PuppetMasterSystem** - Puppet Master eligibility/assignment,
  camera/sabotage grants, elimination, and PM win-check.

## License

No license file yet - add one before treating this as anything other
than a personal/team scaffold.
