# NIGHTFALL — Codebase Guide

## What this is

Top-down horror game built on Love2D. Two-phase loop: plan a run in a menu (Phase 1), then survive a map and extract (Phase 2). One monster per run, procedurally traitened from a point budget the player sets.

---

## Folder structure

```
core/lua/       Engine primitives — no game knowledge, reusable across projects
game/
  data/         Static definitions: items and traits
  entities/     Player and monster
  scenes/       One file per screen (planning, trait reveal, run, result)
  systems/      Stateful subsystems: inventory, pathfinder, shake, extraction (fov.lua exists but unused in 3D)
  ui/           HUD
  world/        Map grid, two map layouts, item spawner
main.lua        Entry point — wires SceneManager and initial scene
```

---

## Engine primitives (core/lua/)

Always use these. Never reimplement what they already do.

| Class | Use it for |
|-------|-----------|
| `Sprite` | Any single drawable rectangle or image |
| `SpriteSet` | Multiple sprites sharing a position, one active at a time |
| `Drawer` | Registering drawables with a priority; calls `draw()` on each in order |
| `Camera` | World-to-screen transform, smooth follow, zoom |
| `Scene` | Pure lifecycle base class; no rendering state |
| `Scene2D` | Subclass of `Scene`; owns a `Drawer` and a `Camera` — use this for all game scenes |
| `SceneManager` | Holds the active scene; drives `update` and `draw` |
| `Timer` | Fires after an interval, preserves remainder for accurate looping |
| `Input` | Action-mapped keyboard polling; call `update()` once per frame |

`Scene2D.new()` creates `self.drawer` and `self.camera`. All game scenes subclass `Scene2D` and override `update`/`draw`/`on_enter`/`on_exit`.

---

## Game loop

```
PlanningScene → TraitRevealScene → RunScene → ResultScene → PlanningScene …
```

`main.lua` boots `PlanningScene`. Each scene switches to the next via:
```lua
require("game/scene_ref").manager:switch(NextScene.new(...))
```

`scene_ref.lua` is a singleton `{ manager = nil }` set at startup to avoid circular requires.

---

## Phase 1 — PlanningScene

Player configures the next run:
- **Map** — Forest Facility or Abandoned Hospital (toggle with `M`)
- **Budget** — 0–7 points (adjust with `Up`/`Down`); controls monster traits AND which loot can spawn
- **Loadout** — one item from the stash into slot 1 (cycle with `L`)

On `Enter`, traits are rolled from `traits.all` (greedy shuffle within budget) and a `RunConfig` table is built:
```lua
RunConfig = {
  map_id         = "forest" | "hospital",
  budget         = number,
  loadout_item   = Item | nil,
  monster_traits = { "sight", "hearing", … },
}
```

`SaveState = { stash = {} }` persists between runs in memory. Max 10 stash items.

---

## Phase 2 — RunScene

RunScene is first-person 3D. It subclasses `Scene3D` (owns `self.raycaster`) and holds a separate `Drawer` for the 2D HUD overlay.

Player position is stored in **1-indexed grid units** (`player.x`, `player.y`). All other systems (monster, extraction, items) still work in **pixel space**; `player:centre()` converts on the fly: `pixel = (gu - 1) * CELL`.

### Startup order (on_enter)
1. Load map (`map_forest` or `map_hospital`)
2. Create `CameraShake`
3. Spawn `Monster` at extraction coords (pixel space)
4. Spawn `Player` at center of spawn cell (grid units): `spawn.x / CELL + 1.5`
5. `ItemSpawner.spawn(map, budget)` → ground items list (pixel space)
6. Create `Extraction`, `HUD`, `Drawer` (HUD registered in drawer)
7. Set `monster.on_kill` callback → death → `ResultScene`
8. Wrap flare gun `use_fn` to gate on `extraction:in_zone()`

### Update order (each frame)
1. `player:update(dt)`
2. `monster:update(dt, player)`
3. Item timers (torch/flashlight burn down)
4. `extraction:update(dt, player)` — `"extracted"` or `"failed"` both transition to `ResultScene`
5. `shake:update(dt)` → store `_shake_angle`

### Draw order (each frame)
1. `raycaster:draw(map, player.x, player.y, player.angle + shake_angle, opts)` — full 3D world pass; fog range and billboard sprite list built each frame
2. `drawer:draw()` — HUD in screen space

---

## Systems

### FOV / visibility

The 2D FOV system has been replaced by **distance fog** in the raycaster. Walls and billboards fade to black beyond `fog_range` cells. RunScene picks the range based on active item:

| Active item | `fog_range` |
|-------------|-------------|
| None / inactive | 8 cells |
| Torch (burning) | 11 cells |
| Flashlight (on) | 14 cells |

`fov.lua` still exists but is unused in RunScene. Monster visibility (`monster.visible`) is no longer toggled — monsters render as billboards whenever they're in front of the player and not wall-occluded.

### Camera shake (`game/systems/camera_shake.lua`)

`trigger(magnitude)` starts a shake. Magnitude decays to 0 over 0.15 s.

In 3D, shake is applied as an **angle wobble** on the raycaster view: `shake:angle_offset()` returns `±magnitude × 0.008` radians (magnitude 6 → ≈ ±3°).

`offset()` (returning pixel ox/oy) still exists for potential 2D use.

Monster step timer calls `shake:trigger` based on distance:
- > 10 cells → nothing
- 6–10 → magnitude 1
- 3–6 → magnitude 3
- < 3 → magnitude 6

### Inventory (`game/systems/inventory.lua`)

5 slots, all `nil` by default. Active slot index 1–5.

Key methods: `pick_up(item)`, `drop()`, `swap_with_ground(item)`, `cycle(dir)`, `active()`, `has_item(id)`, `remove_active()`, `remove_item_by_ref(item)`.

Player controls: `Q`/`E` cycle, `1`–`5` jump, `F` use, `G` pick up / drop.

### Pathfinder (`game/systems/pathfinder.lua`)

A* on the map grid, 4-directional, Manhattan heuristic. Returns `{ {col,row}, … }` from start to goal inclusive, or `nil` if no path. Capped at 2000 nodes.

Used only by monster WANDER/ALERTED/SEARCH states. Monster ignores wall collision for actual movement (walks through walls) — pathfinding is only used to pick destinations during wander.

### Extraction (`game/systems/extraction.lua`)

`try_start(player)` — starts 60 s countdown if player is inside `map.extraction.radius`. Returns true/false.

`update(dt, player)` returns:
- `"extracted"` when timer hits 0 and player is in zone
- `"failed"` when timer hits 0 and player is not in zone
- `nil` otherwise

`discovered` flips true the first time `in_zone` is true — used by HUD to show the extract indicator.

---

## Entities

### Player (`game/entities/player.lua`)

- Position stored as **1-indexed grid units** (`self.x`, `self.y`); `self.angle` is facing direction in radians
- `BASE_SPEED = 120` px/s — exported so monster can read it; internal move speed is `BASE_SPEED / CELL ≈ 3.75` GU/s
- Controls: `W`/`S` move forward/back along facing angle; `A`/`D` turn at 2.2 rad/s
- Wall collision: `can_move(map, x, y)` checks 4 corners of a 0.25-cell margin around the new position
- `centre()` converts to pixel space: `{ x = (self.x - 0.5) * CELL, y = (self.y - 0.5) * CELL }` — used by monster, extraction, and item pickup. The `-0.5` offset gives the true sub-cell centre for any fractional GU position.
- `active_item()` — convenience wrapper over `inventory:active()`

### Monster (`game/entities/monster.lua`)

Speed constants:
```
WANDER_SPEED = BASE_SPEED * 0.35   -- slow creep
CHASE_SPEED  = BASE_SPEED * 0.85   -- fast but beatable
SPEED_BOOST  = BASE_SPEED * 0.25   -- added if Speed trait
```

State machine: `wander → alerted → chase → search → wander`

Trait implementations:
- **Sight** — LOS raycast (1 px steps), 12 cells, wall-blocked. Instant chase. Loses player after 3 s without LOS. Also triggers if player has active torch (`player:active_item().active == true`).
- **Speed** — sets `has_speed = true`, adds `SPEED_BOOST` to all movement.
- **Smell** — `Timer(2.5)`: every 2.5 s, unconditionally sets `last_known_pos` and goes ALERTED. Global, no range, no wall blocking.
- **Hearing** — every frame: if `player:is_moving()` and distance < 8 cells → ALERTED.

Kill distance: `d_px < 48` pixels (1.5 cells) — fires **unconditionally every frame** regardless of state (before the state machine runs), so the player can be killed during wander, alerted, chase, or search. The nil-guard `and self.on_kill` is present.

`on_kill` callback is set by RunScene to trigger the death flow.

---

## Items (`game/data/items.lua`)

Always instantiate with `items.new(id)` — returns a fresh table. Never share item instances between slots.

| Item | Value | Key behaviour |
|------|-------|---------------|
| Torch | 1 | Active when in any slot and `use_fn` called. Burns 90 s. Monster Sight detects glow. Extends fog range to 11 cells. |
| Flashlight | 1 | Toggle on/off with `F`. Burns 120 s total (regardless of on/off). Extends fog range to 14 cells. |
| Flare Gun | 0 | `use_fn` returns `"extract"`. RunScene intercepts this and calls `extraction:try_start` only if player is in zone. Renders as a pink billboard. |

Items only spawn if their `value ≤ budget`. Flare gun (`value=0`) always spawns.

---

## Maps (`game/world/`)

Both maps are 40×30 cells, cell size 32 px (1280×960 world px). Grid values: `1` = floor, `2` = wall.

`map:is_wall(col, row)` returns true for walls and out-of-bounds.
`map:world_to_cell(wx, wy)` and `map:cell_to_world(col, row)` convert between coordinate spaces.

Both maps use a grid of rooms connected by 1-cell-wide hallways. Room sizes and hallway lengths are deliberately varied (S/M/L) so different parts of the map have different sightline lengths and encounter distances.

### Forest Facility (`map_forest.lua`)

4×3 grid of 12 rooms. Each room's dimensions are determined by its column width × row height.

**Column widths:** A=8 (L), B=4 (S), C=6 (M), D=8 (L)
**Row heights:** 1=6 (M), 2=4 (S), 3=8 (L)
**Horizontal gaps (hallway length):** A–B=2 (S), B–C=6 (L), C–D=4 (M)
**Vertical gaps (hallway length):** rows 1–2=4 (M), rows 2–3=6 (L)

```
cols:  2–9    10–11  12–15  16–21  22–27  28–31  32–39
       [A  L ] [S]   [B S]  [ L ]  [C M ] [ M ]  [D  L ]
rows:
2–7    A1 8×6  ──    B1 4×6  ────  C1 6×6  ──    D1 8×6    (M height)
8–11    │(M)         │(M)          │(M)           │(M)
12–15  A2 8×4  ──    B2 4×4  ────  C2 6×4  ──    D2 8×4    (S height)
16–21   │(L)         │(L)          │(L)           │(L)
22–29  A3 8×8  ──    B3 4×8  ────  C3 6×8  ──    D3 8×8    (L height)
```

- Spawn: pixel (5×CELL, 4×CELL) — room A1, top-left
- Extraction: pixel (35×CELL, 25×CELL) — room D3, bottom-right

### Abandoned Hospital (`map_hospital.lua`)

5×4 grid of 20 rooms.

**Column widths:** A=4 (S), B=6 (M), C=4 (S), D=7 (L), E=5 (M)
**Row heights:** 1=4 (S), 2=5 (M), 3=6 (L), 4=5 (M)
**Horizontal gaps:** A–B=2 (S), B–C=5 (L), C–D=3 (M), D–E=2 (S)
**Vertical gaps:** rows 1–2=2 (S), rows 2–3=3 (M), rows 3–4=2 (S)

The D column rooms are notably wider (7 cells), creating bigger spaces mid-map. The long B–C hallways (5 cells) are the most exposed stretches on the map.

- Spawn: pixel (2×CELL, 2×CELL) — room A1, top-left
- Extraction: pixel (37×CELL, 26×CELL) — room E4, bottom-right

---

## Traits (`game/data/traits.lua`)

```lua
traits.sight   -- cost 2
traits.speed   -- cost 1
traits.smell   -- cost 1
traits.hearing -- cost 1
traits.all     -- flat list for iteration
```

Trait rolling (in PlanningScene): shuffle `traits.all`, greedily pick traits while cumulative cost ≤ budget. Each trait at most once per run.

---

## Adding things

**New item**: add a factory function in `items.lua` following the `make_torch` pattern. Give it a `value`. It will auto-appear in spawner if `value ≤ budget`. Wire `use_fn` to return a string signal if RunScene needs to react.

**New trait**: add to `traits.lua` with a cost and an `apply(monster)` stub. Implement the behaviour in `monster.lua`'s update loop checking `self.has_<traitname>`.

**New map**: create `game/world/map_<name>.lua` following the `fill_rect` pattern. Add it to the map picker in `planning_scene.lua` and the loader in `run_scene.lua`.

**New scene**: subclass `Scene` (or just follow the same metatable pattern). Register it in `main.lua` or transition to it via `scene_ref.manager:switch(...)`.
