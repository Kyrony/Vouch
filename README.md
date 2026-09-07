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
   seconds). From a **fresh git clone** (no `.godot/` folder yet), run
   once before Play:

   ```bash
   godot4 --headless --path . --import
   ```

   The editor normally builds this cache on first open; the command above
   is the headless equivalent James/Kyle can use from CI or a terminal.
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
5. Both instances load into the Match scene. Each player spawns **dead center**
   inside a clean empty graybox bunker (`PlayerSpawn` at local `(0, 0, 0)` —
   feet on floor). Escape door is on the **+Z** wall.

To test across two real machines on the same network instead: host on
one machine, then on the other type the host's LAN IP into the Join
field. There's no lobby-code/relay system yet (see below), so direct IP
is required for now. The Play screen shows a disabled **Lobby code**
field as a placeholder — session codes are post-MVP.

## Controls

### Horror neighborhood chase (default)

| Role | Action | Key |
| --- | --- | --- |
| All | Move / Look / Jump | `W A S D` / Mouse / `Space` |
| Survivor | Pick up item | `E` |
| Survivor | Find missing child (near glow marker) | `E` |
| Survivor | Use selected hotbar item / toggle **phone LED** | `R` |
| Survivor | Drop selected item | `G` |
| Survivor | Select hotbar slot | `1`–`8` |
| Puppet Master | Possess dead family body / body swap (near target) | `Q` |
| Puppet Master | Float upward (hold) | `Space` (in air) |
| Puppet Master | Life steal aura (radius, then cooldown) | `E` |
| All | Pause / release mouse | `Esc` |

**Goal:** Each **family team** spawns in their own **1-story house bedroom** (A–D around the cul-de-sac). One missing child is hidden at a random location among **11 alive-only spawn pins** (Leonardo L2 SoT ids). Find the child marker, then reach the **soft-gated field exit** (west yard, unmarked — master sheet has no escape routes). Trust tools are **phone + live radio masts** (service / weak / dead radii, 3 active per match, one forced near the PM). The **Puppet Master** hunts from the **east PM mansion** — radius life-steal aura with neon ring + recharge. PM wins if all survivors are drained before families escape with the child.

Legacy sealed-room / tunnel modes: `VOUCH_BUNKER_ONLY=1` or `VOUCH_ESCAPE_PATH=1`.

### Legacy controls

| Action | Key (remappable in Settings) |
| --- | --- |
| Move | `W A S D` |
| Look | Mouse (sensitivity adjustable in Settings) |
| Jump | `Space` |
| Crouch | `Ctrl` (hold) |
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
- **Hand-sealed graybox rooms (friends-MVP)**: six perfect axis-aligned bunker
  boxes (`Room_01`–`Room_06`) + sealed `Room_PM`. Floor/walls/ceiling only;
  one **+Z** door opening; `PlayerSpawn` at geometric center `(0, 0, 0)`.
  Mesh = collision on every piece. **Bunker-only default:** no tunnels, hub,
  item props, phone, or walkie (`VOUCH_ESCAPE_PATH=1` for full loop).
- **16-slot item spawn**: every room has **16 fixed `ItemSpawnSlot` markers**.
  At match start `ItemSpawnSystem` shuffles which slot each interactable
  (phone, switch, camera, valve, ladder, props, etc.) occupies — no free-float
  placement.
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
- **Mystery controls** (`scripts/systems/link_graph.gd`): light switches,
  water valves, and gas valves secretly wired to a light, broken pipe, or
  gas leak in *someone else's* room, with a mathematically guaranteed
  derangement - no control ever links back to its own room. You get
  ambiguous local feedback (a "tick"), they get a clear local event.
- **Room utilities** (`scripts/autoload/room_utilities.gd`): each room
  tracks **Power / Water / Gas / Communication**. Lights need power,
  flooding needs water utility, phones need comms. An **electrical box**
  puzzle (3 broken wires + live wire) can route power to another room.
- **Flooding**: activate a linked water valve to **slowly trickle** water
  into a *different* room over time (host-authoritative, tunable rate) —
  slows movement for anyone standing in it and can physically block
  escape past a threshold.
- **Code-lock puzzles** with a **physical digit keypad** (press digits
  one at a time - a teammate can dictate a code over the phone). Codes
  are discoverable as a book or a **grabbable flame-lit paper**: carry it
  near a flame to reveal the code, but get too close for too long and it
  catches fire and is destroyed.
- **Movable & destroyable props**: a bookcase can be pushed aside to
  reveal a hidden hallway/vent; each room's phone and security camera
  can be destroyed by **holding** `F` (a HUD progress bar shows the
  hold), host-authoritative and replicated. The security camera is
  mounted near the ceiling and needs its room's **ladder** (climbable,
  **pick up and place** against the nearest wall, real climbing physics)
  to reach.
- **Phone**, redesigned: unknown/random line, text-first, tagged with an
  anonymous per-match "line id". **Click any contact to rename it**
  locally (`scripts/autoload/contact_book.gd`) - a personal memory aid,
  never synced to anyone else; the rename flow works by mouse click or
  by keyboard/gamepad focus + confirm.
- **Walkie-talkie**: faction-paired text channel between two teammates (`WalkieSystem` + room pickup). Open with **E** on the walkie prop; type and send like a private radio stub.
- **Pipe bandage**: pickup item that seals a room's broken pipe / gas leak when used.
- **Escape + win-check** (`scripts/systems/escape_system.gd`): open your
  escape door/vent (animated swing/slide — walk through, no teleport),
  follow a **concrete bunker tunnel** to the shared hub, climb the shaft
  stairwell, and emerge on the **mountain clearing** (`Outside` at surface).
  Enter the escape zone to register your escape. The first faction with **all**
  members escaped wins — logged to console (`[EscapeSystem] MATCH OVER - ...`).
- **World v2 interactables**: grabbable **ladder** (place, lean into wall,
  climb), **fireplace** with floor gas line, physics **books** that burn,
  **drains** / **exhaust vents**, optional **loft stairs** and denser prop
  scatter. Wall-mounted **phone**, **light switch**, and **camera** snap
  flush to the nearest wall.
- **Binary terminal** puzzle: flip bits to match a target number; unlock
  moves a bookcase and powers a peek monitor into another room.
- **Esc pause menu** (`scenes/PauseMenu.tscn`): Resume, Settings hint,
  Exit to Home, Debug GUI — **REMOVE DEBUG GUI FROM PAUSE MENU BEFORE
  FINAL LAUNCH**.
- **Player movement stub**: first-person `CharacterBody3D` with
  authority-gated input, ladder-climbing physics, and replicated
  transform via `MultiplayerSynchronizer`.
- **Host spawn odds UI**: cleaner labels; **host-only** editable sliders,
  clients see a read-only notice (`scripts/lobby.gd`).
- **Debug GUI** (`scripts/debug_gui.gd`, toggle **Home** key): host-only
  spawn/test buttons — **REMOVE OR GATE BEFORE RELEASE**.
- **\*\*\* TEST-ONLY, REMOVE BEFORE FULL RELEASE \*\*\*** - a pickup gun
  firing **visible projectiles** (`TestProjectile`) and dummy targets in
  the Outside courtyard for hit-registration testing. See "Test-only
  tools" below.

## What's explicitly NOT implemented (don't assume otherwise)

- **Voice comms.** Walkie-talkie text stub exists; no voice yet.
- **Lobby codes / matchmaking / relay.** Direct IP only - no NAT
  traversal, no session codes.
- **Fully hand-authored/varied room shapes.** **20 distinct fixed room maps**
  at human metric scale (`scripts/world_scale.gd`) — each a single sealed scene,
  graybox but intentionally composed. James floor plans are visual inspiration
  only; not runtime assembly.
- **Post-escape interactions from Outside.** It's a neutral holding area
  with no sabotage/mechanics in MVP.
- **PA announcements and window/note comms.** Called out in the design
  doc as planned, not built - only the phone stub exists so far.
- **More than one sabotage verb for the Puppet Master**, and four utility
  channels (light/power, flood/water, gas, comms) — gas is a stub effect.
- **Puzzle gating for anything besides escape.** The core is reusable for
  camera/feature gating, but only escape is wired up.
- **Real fluid simulation for flooding.** A single rising water plane
  with a flat speed/escape penalty, no drainage.
- **Character screen.** Stub panel only, no functionality.
- **Anti-cheat / server-side movement validation.**
- **Real art.** Everything is graybox on purpose.

Every stub above has a `TODO(post-MVP)` comment at its definition site
pointing at what's missing.

## Horror child spawn points (11, alive-only)

Host RNG picks **one** per match (`ChildSpawnRNG`). Teams map to **families** A–D (cul-de-sac bedroom spawns). All pins are living hides — no grave sites. IDs are Leonardo L2 SoT **eng short names**. Art map labels are deferred.

| # | `spawn_id` | Callout | Location |
| --- | --- | --- | --- |
| 1 | `pm_attic` | PM ATTIC | PM mansion attic |
| 2 | `master_bedroom` | PM MASTER BEDROOM | PM mansion master bedroom |
| 3 | `bunker_utility` | PM BUNKER UTILITY CLOSET | PM bunker utility closet |
| 4 | `basement` | PM BASEMENT | PM basement |
| 5 | `uncle_bedroom` | UNCLE BEDROOM | Uncle house bedroom |
| 6 | `uncle_garage` | UNCLE GARAGE | Uncle garage |
| 7 | `family_shed` | FAMILY SHED | Shed by family houses |
| 8 | `storm_drain` | STORM DRAIN | Street storm drain |
| 9 | `under_porch_crawl` | UNDER-PORCH CRAWL / DIRT HIDE | House A porch crawl (no grave) |
| 10 | `garden_well` | GARDEN WELL / CRAWLSPACE | Garden well / crawlspace |
| 11 | `car_trunk` | CAR TRUNK (CURB) | Parked car trunk at curb |

See [`docs/blueprints/v0.5/`](docs/blueprints/v0.5/) for Leonardo v0.5 sheets.

**Towers (soft-go):** many candidate masts; **3 active per match**; **1 forced near the PM**. Phone + mast use **service / weak / dead** radii. Scratch on the slate only (not a voice or SMS line).

**HUD + smartphone (soft-go):** Leonardo’s v2 neon-horror icon language is wired in `scripts/horror/ui/neon_hud.gd` and `assets/horror/hud/` (heart / cyan pulse / violet glitch-eye / yellow **phone LED** / signal full-weak-dead). The inventory `phone` is diegetic `ITEM_DEVICE_SMARTPHONE_01` — graphite/gold mesh, camera LED spotlight, eng-tunable battery drain on `PhoneDevice`. Sheet ~15%/min LED and ~2%/min passive are concept only. No handheld flashlight item. Textures are wiring refs; Leonardo may redraw them before Steam.

**Environment kits (soft-go):** Family houses use modular porch / foundation / stairs / crawl graybox (`under_porch_crawl` under house A — no grave wording). PM bunker gets sealed concrete + pipes/shelves and a utility closet for `bunker_utility` (red/yellow neon, fluorescent; no gore, no guns). See `assets/horror/kits/README.md`. Kit plan sizes are art targets; live footprints stay v0.5.

**HUD:** neon heart (health), cyan bar (stamina), violet bar (fear), phone + spotty signal.

## Friends-ready playtest (James checklist)

Use this before a friends session. Each item maps to a GDD MVP check:

| # | Check | Pass criteria |
| --- | --- | --- |
| 1 | **Start Match** | Host sees joined list → Start Match loads both clients into rooms |
| 2 | **Spawn alone** | Each player spawns in their own sealed room |
| 3 | **Mystery link** | Flip light switch → local “tick” toast; another room’s light/flood changes |
| 4 | **Phone beat** | Pick up phone → compose/send text (random recipient stub) |
| 5 | **Walkie beat** | Pick up walkie → faction-pair text panel opens and sends |
| 6 | **Escape Outside** | Open door/vent → walk tunnel + shaft stairs → enter clearing zone |

**Test gun / Outside range:** gated off unless `VOUCH_DEBUG_BUILD=1` or a Godot debug export. Remove entirely before retail.

**Lobby codes:** not implemented — join with direct IP (stub field on Play screen documents this).

## Script ownership (playability pass — 10 tasks)

| Task | Feature | Owner script(s) |
| --- | --- | --- |
| 1 | Stairs → valid landings | *(frozen — graybox rooms have no stairs)* |
| 2 | Puzzle / RPC audit | `scripts/systems/link_graph.gd`, `scripts/interactables/*` (switches, valves, terminal, electrical) |
| 3 | Verticality (ramps, mezz) | `scripts/rooms/tunnel_kit.gd`, `scripts/rooms/room_map.gd`, `scripts/systems/escape_hub.gd`, `scripts/rooms/room_layouts.gd` |
| 4 | UI skin | `scripts/ui/ui_theme.gd`, `scripts/lobby.gd`, `scripts/rooms/neon_theme.gd` |
| 5 | Item glow feedback | `scripts/interactables/interactable.gd`, `scripts/player.gd` |
| 6 | Item sync fixes | `scripts/interactables/ladder.gd`, `flammable_prop.gd`, `clue_flame_paper.gd` |
| 7 | Water (stylized rule) | `scripts/interactables/broken_pipe.gd`, `scripts/interactables/drain.gd`, `scripts/systems/escape_system.gd` |
| 8 | Fire (stylized rule) | `scripts/systems/fire_system.gd`, `scripts/interactables/fireplace.gd`, `flammable_prop.gd` |
| 9 | Playable loop strip | `scripts/match.gd`, `scripts/room_pod.gd`, `scripts/autoload/match_settings.gd` |
| 10 | Friends-ready gate | `scripts/autoload/debug_build.gd`, `scripts/outside.gd`, `scripts/debug_gui.gd`, `README.md` |

## Script ownership (room interiors)

Each concern lives in one script/class. Brief map for the 10 interior-polish systems:

| # | Feature | Owner script(s) |
| --- | --- | --- |
| 1 | Attachment headless tests | `scripts/main.gd` (`VOUCH_*` flags), `scripts/rooms/spawn_attachment_validator.gd` |
| 2 | Room scale / climbable stairs | `scripts/world_scale.gd`, `scripts/rooms/graybox_layouts.gd` |
| 3 | Hover / target highlight | `scripts/interactables/interactable.gd` (`set_highlighted`), `scripts/player.gd` (`_set_highlight`) |
| 4 | Retro neon accents | `scripts/rooms/neon_theme.gd`, accent materials via `room_map.gd` |
| 5 | Spawn / slot orchestration | `scripts/rooms/item_spawn_system.gd`, `scripts/rooms/item_spawn_slot.gd`, `scripts/rooms/room_map.gd` |
| 6 | Camera ceiling/wall slots | `scripts/rooms/item_spawn_slot.gd` (`ceiling`), `scripts/rooms/item_spawn_system.gd` (camera → ceiling) |
| 7 | Player crouch | `scripts/player.gd`, `scripts/autoload/settings_manager.gd`, `project.godot` `crouch` action |
| 8 | Walkie-talkie comms | `scripts/systems/walkie_system.gd` (autoload), `scripts/interactables/walkie_talkie.gd`, `scripts/player.gd` (HUD panel), `scripts/match.gd` (pairing) |
| 9 | Visible pipes / gas lines | `scripts/rooms/room_utilities_visual.gd`, called from `item_spawn_system.gd` |
| 10 | Pipe bandage repair | `scripts/interactables/pipe_bandage.gd`, `broken_pipe.gd` / `gas_leak.gd` (`server_repair`) |
| 11 | Graybox spawn inside AABB | `scripts/rooms/graybox_spawn_validator.gd`, `PlayerSpawn` markers in each `Room_XX.tscn` |

Headless validation:

```bash
# Player script + Match spawn path (catches parse-time class_name deps)
VOUCH_PLAYER_SCRIPT_TEST=1 godot4 --headless --path .

# Cold-clone check (no .godot cache) — should pass after player.gd hardening:
rm -rf .godot
godot4 --headless --path . -s res://scripts/vouch_player_spawn_probe.gd

VOUCH_HORROR_MATCH_TEST=1 godot4 --headless --path .

# Horror neighborhood smoke (standalone probe):
godot4 --headless --path . -s res://scripts/vouch_horror_match_probe.gd

# Playable loop (phone/walkie) — bunker-only: VOUCH_BUNKER_ONLY=1; full escape path needs VOUCH_ESCAPE_PATH=1:
VOUCH_PLAYABLE_LOOP_TEST=1 godot4 --headless --path .
VOUCH_ESCAPE_PATH=1 VOUCH_PLAYABLE_LOOP_TEST=1 godot4 --headless --path .
godot4 --headless --path . -s res://scripts/vouch_playable_loop_probe.gd

VOUCH_ROOM_SPAWN_TEST=1 godot4 --headless --path .
VOUCH_MATCH_SPAWN_TEST=1 godot4 --headless --path .
VOUCH_ATTACHMENT_TEST=1 godot4 --headless --path .
```

## Test-only tools (*** REMOVE BEFORE FULL RELEASE ***)

Gated by `DebugBuild` (`scripts/autoload/debug_build.gd`): enabled only when
`VOUCH_DEBUG_BUILD=1` is set or the export is a Godot debug build. When disabled,
the Outside `TestRange_RemoveBeforeRelease` node is removed at runtime and the
debug menu cannot spawn guns.

The Outside courtyard has a `TestRange_RemoveBeforeRelease` node with a
pickup `Gun`, **`TestProjectile`**, and a few `DummyTarget` props, used solely to manually
verify multiplayer hit-registration during development - no ammo, no
damage model, no gameplay purpose. Before shipping, remove:
`scripts/interactables/gun.gd`, `scripts/interactables/dummy_target.gd`,
`scripts/interactables/test_projectile.gd`, `scripts/debug_gui.gd`,
`scenes/DebugGui.tscn`, the `fire` input action in `project.godot`, the
`has_gun`/`_fire_gun()` bits in `scripts/player.gd`, and the
`TestRange_RemoveBeforeRelease` node from `scenes/Outside/Outside.tscn`.

## Project structure

```
project.godot              Godot 4 project config (autoloads, input map, etc.)
scripts/horror/            Horror neighborhood factory (default play mode)
  characters/              PuppetMasterData, possession constants
  environment/             FamilyHouse, PMMansion, UncleHouse, Outdoor graybox builders
  items/                   EffectDefinitions, PlayerEffects (meter stacks)
  world/                   NeighborhoodV05, NeighborhoodLayout, ChildSpawnRNG (11 L2 SoT pins), TowerRules
  ui/                      Neon HUD (heart / cyan / violet / phone signal) + neon menu
  horror_world.gd          World orchestrator
  match_horror.gd          Host-authoritative horror match builder
  puppet_master_controller.gd  PM float, possession, radius life-steal
scenes/Horror/             HorrorWorld.tscn, WorldPickup, PMChaseAI
scenes/
  Main.tscn                 Actual main scene: composes Lobby (Home) + World (Match+Outside)
  Lobby/Lobby.tscn           Home screen: Play/Settings/Character/Exit, joined-player list,
                             match spawn odds, key remap + sensitivity + volume controls
  Match/Match.tscn           Match director (spawns rooms + players)
  Match/RoomPod.tscn         Multiplayer shell — instances scenes/Rooms/Room_XX.tscn
  scenes/Rooms/              6 hand-sealed graybox rooms + Room_PM.tscn
  scripts/rooms/             RoomMap, graybox layouts, 16-slot item spawn
  Match/Props/               Small graybox decoration scenes (crate/shelf/barrel)
  Match/Interactables/       Ladder.tscn (climbable + movable)
  DebugGui.tscn              Dev/host debug panel (Home key — remove before release)
  Outside/Outside.tscn       Shared mountain clearing (post-escape) + test-only gun/dummy range
  Player/Player.tscn         First-person player pawn + HUD (phone/keypad/camera/eliminated panels)
scripts/
  main.gd, match.gd, outside.gd, lobby.gd, player.gd, room_pod.gd
  autoload/                  GameState, FactionData, NetworkManager, ContactBook,
                             SettingsManager, MatchSettings, RoomUtilities
  systems/                   LinkGraph, PhoneSystem, WalkieSystem, EscapeSystem, PuzzleSystem, PuppetMasterSystem
  interactables/              Interactable base (+ destroy mixin) and every prop type:
                              LightSwitch, WaterValve, Door (door/vent), Phone, WalkieTalkie, PipeBandage,
                              RoomLight, BrokenPipe, SecurityCamera, Ladder, CodeKeypad, ClueBook,
                              ClueFlamePaper, Flame, MovableProp, ElectricalBox,
                              GasValve, GasLeak, Gun*, DummyTarget*,
                              TestProjectile* (* test-only)
assets/
  materials/                  Shared graybox materials + default environment
  brand/                       Small in-engine copy of the Vouch icon
docs/
  MVP_GDD.md                  Design locks / what's in vs. out of MVP
  blueprints/v0.5/            Leonardo Neighborhood Layout v0.5 sheets + L2 SoT
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
- **RoomUtilities** - per-room power/water/gas/comms state, replicated
  for local feedback.
- **PlayerHealth** - horror mode HP drain/heal (host-authoritative).
- **PlayerInventory** - horror survivor 8-slot hotbar.
- **PlayerEffects** - fear/stamina meters + timed effect stacks (life-steal aura cooldown).
- **ChildSpawnRNG** - per-match missing-child location (1 of 11 alive-only pins).
- **TowerRules** - 3 live masts per match (1 forced near PM); phone + tower radii.
- **LinkGraph** - mystery control/effect registry and guaranteed-no-
  self-link resolution.
- **PhoneSystem** - random-recipient text routing + per-match line ids.
- **WalkieSystem** - host-authoritative faction-pair text comms (walkie-talkie MVP).
- **EscapeSystem** - escape handling + faction win-check + flood-block
  check.
- **PuzzleSystem** - code-lock registry and unlock attempts.
- **PuppetMasterSystem** - Puppet Master eligibility/assignment,
  camera/sabotage grants, elimination, and PM win-check.

## License

No license file yet - add one before treating this as anything other
than a personal/team scaffold.
