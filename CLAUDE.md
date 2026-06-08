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
  scenes/       One file per screen (planning, trait reveal, run, result, settings_menu)
  systems/      Stateful subsystems: inventory, pathfinder, shake, extraction (fov.lua exists but unused in 3D)
  ui/           HUD
  world/        Map grid, two map layouts, item spawner
  settings_state.lua   SettingsState — fullscreen bool + toggle_fullscreen()
main.lua        Entry point — wires SceneManager, SettingsState, SettingsMenu, and initial scene
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
| `SceneManager` | Holds the active scene; drives `update` and `draw`; animates a 0.3 s black-rect fade between scene transitions |
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

### Settings menu

`main.lua` also owns a `SettingsState` and a `SettingsMenu` instance (normal game path only). `SettingsState` is constructed at module level; `SettingsMenu.new(ss)` is called inside `love.load()` after `love.window.setMode` — **never at module level**, because `SettingsMenu.new` calls `love.graphics.newImage` and `love.graphics.newFont`, which require the graphics subsystem to be fully initialised (calling them before `love.load` hangs on headless CI runners with no display).

Pressing `Escape` in any scene that has `self.esc_opens_settings = true` opens the overlay. If `self.esc_settings_opaque = true` (PlanningScene), the overlay draws a full background; otherwise (RunScene) it draws a semi-transparent dim rect. While open, `love.update` calls `settings_menu:update(dt)` instead of `manager:update(dt)`, pausing the game. `love.draw` always calls `manager:draw()` then draws the overlay on top.

`SettingsMenu` reads `love.keyboard.isDown` directly with edge-trigger `_prev_*` flags. Items: **Fullscreen / Window** (calls `settings_state:toggle_fullscreen()`), **Exit Settings** (closes overlay), **Leave Game** (`love.event.quit()`).

---

## Web build

The game deploys to GitHub Pages as a playable web build via love.js.

```
npm install          # installs love.js@11.4.1
npm run build        # runs scripts/build_web.sh → outputs to web/
```

`scripts/build_web.sh` zips `main.lua conf.lua assets/ core/ game/` into a `.love` archive, passes it through love.js, then injects `web-template/controls.js` (touch/WASD overlay) into the output HTML.

CI (`.github/workflows/web.yml`) does this automatically:
- Push to `master` → deploys to `https://ivankhyung.com/horror-game/`
- Open/update a PR → deploys a preview to `https://ivankhyung.com/horror-game/pr-N/` and posts a comment with the link
- Close a PR → removes the `pr-N/` directory from gh-pages

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
3. Item timers (flashlight burn down)
4. `extraction:update(dt, player)` — `"extracted"` transitions to `ResultScene`
5. `shake:update(dt)` → store `_shake_angle`

### Draw order (each frame)
1. `raycaster:draw(map, player.x, player.y, angle, opts)` — walls-only 3D pass; builds `z_buffer`
2. `raycaster:draw_sprites(sprites, player.x, player.y, angle, lights)` — image-based billboards (monster, items, extraction, torches), z-buffer occluded, fog-lit
3. `drawer:draw()` — HUD in screen space

`angle` is `player.angle + _shake_angle`. The same `lights` table is passed to both raycaster calls. `build_sprites()` in RunScene assembles the sprite list; images are lazy-loaded and cached in a module-level `_images` table via the `img(path)` helper.

---

## Systems

### FOV / visibility

The 2D FOV system has been replaced by **light-based fog** in the raycaster. Walls and billboards are only visible within range of point lights; everything else is pitch black. Two light sources exist:

- **Wall torches** — static point lights (radius 6) placed around the map
- **Flashlight** — when any inventory slot holds a flashlight that is `active` and `on`, RunScene adds a player-centred point light (radius 6) each frame, extending how far the player can see

`fov.lua` still exists but is unused in RunScene. Monster visibility (`monster.visible`) is no longer toggled — monsters render as image-based billboards (`assets/sprites/monster.png`) whenever they're in front of the player and not wall-occluded. All billboards (monster, items, extraction zone, torches) are PNG images loaded from `assets/sprites/` and drawn via `raycaster:draw_sprites()`.

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

`try_start(player)` — starts 30 s countdown if player is inside `map.extraction.radius`. Returns true/false.

`update(dt, player)` returns:
- `"extracted"` when timer hits 0 and player is in zone, or when `is_ready()` is true and player enters zone
- `nil` otherwise — if the timer fires and the player is out of zone, `_ready` is set to true and extraction stays "hot"

`is_ready()` — returns true after the countdown has elapsed but the player has not yet stepped back in; used by HUD to show a pulsing `"RETURN TO EXTRACT"` label.

`discovered` flips true the first time `in_zone` is true — used by HUD to show the extract indicator.

---

## Audio (`game/sound.lua`)

`Sound` is a module-level singleton — no `new()`, just `require("game/sound")` and call the functions directly. Wire it once in `main.lua`: `Sound.load()` after `love.window.setMode`, and `Sound.update(dt)` at the top of `love.update`.

Every function opens with `if not love.audio then return end`, so all calls are safe no-ops in headless test mode (where `love.audio` is nil).

### SFX events

Loaded as static sources from `assets/sounds/<name>.wav`; each `Sound.play(name)` clones the source and plays the clone so overlapping calls never cut each other off. Missing files are silently skipped at load time.

| Event name | When triggered |
|---|---|
| `"monster_step"` | Monster step timer fires (once per 0.5 s tick); volume is distance-based: full (≤4 cells), half (≤8), faint (≤12), silent beyond |
| `"item_pickup"` | Player picks up a ground item |
| `"item_use"` | Player uses the active item |
| `"extraction_start"` | `extraction:try_start()` succeeds (flare gun in zone) |
| `"extraction_ready"` | Extraction countdown completes but player is out of zone |
| `"player_death"` | `monster.on_kill` fires |
| `"win"` | ResultScene entered with outcome `"extracted"` |
| `"lose"` | ResultScene entered with outcome `"death"` |

### Music tracks

Loaded as streaming looping sources from `assets/music/<name>.wav` or `.mp3` (tries both extensions). Drop audio files into those directories to activate them.

| Track | Scene | Behaviour |
|---|---|---|
| `"menu"` | PlanningScene | `play_music("menu")` on `on_enter`; `stop_music("menu")` before switching to run |
| `"ambient"` | RunScene (calm) | `play_music("ambient")` on `on_enter`; `stop_music("ambient")` on `on_exit` |
| `"chase"` | RunScene (combat) | `fade_music("chase", 1, 1.0)` + `fade_music("ambient", 0, 1.0)` when monster enters CHASE; reversed over 2 s when monster leaves CHASE |

Chase music transitions are driven by RunScene detecting changes to `self.monster.state` each frame, comparing against `self._prev_monster_state`.

### API

```lua
Sound.load()                        -- load all present assets; call once
Sound.update(dt)                    -- advance fade ramps; call every frame
Sound.play(name, volume)            -- fire-and-forget SFX; volume 0–1, defaults to sfx volume
Sound.play_music(name)              -- start music immediately at full volume
Sound.fade_music(name, target, secs) -- smooth volume ramp
Sound.stop_music(name)              -- stop and rewind
Sound.is_music_playing(name)        -- bool
Sound.set_sfx_volume(0..1)
Sound.set_music_volume(0..1)
```

Asset directories: `assets/sounds/` and `assets/music/` (both currently empty; tracked in git via `.gitkeep`).

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
- **Sight** — LOS raycast (1 px steps), 12 cells, wall-blocked. Instant chase. Loses player after 3 s without LOS. Also triggers if any inventory slot holds a flashlight that is `active` and `on` (regardless of which slot is selected).
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
| Flashlight | 1 | Toggle on/off with `F`. Burns 120 s total (regardless of on/off). While on, adds a player-centred point light (extending visibility) and triggers monster Sight glow detection — both effects apply from any inventory slot, not just the active one. |
| Flare Gun | 0 | `use_fn` returns `"extract"`. RunScene intercepts this, calls `extraction:try_start` only if player is in zone, then removes the item from inventory. Renders as an image billboard (`assets/sprites/flare_gun.png`). |
| Compass | 3 | Passive. While held as the active item, the HUD draws a directional arrow pointing toward the extraction zone. No use_fn. |
| Tracker | 1 | Passive. While held as the active item, the HUD draws a red directional arrow pointing toward the monster. No use_fn. |
| Adrenaline Shot | 2 | Press `F` to inject. Boosts movement speed by 1.75× for 5 s, then enters a 20 s cooldown. The boost and cooldown continue in any inventory slot — switching away does not cancel the effect. `speed_mult` is read by scanning all slots, not just the active one. |
| Taser | 5 | Press `F` to fire. Stuns the monster for 4 s if it is within 96 px (3 cells). Always consumed on use — no refund if out of range. |

Items only spawn if their `value ≤ budget`. Flare gun (`value=0`) always spawns.

---

## Maps (`game/world/`)

Both maps are 40×30 cells, cell size 32 px (1280×960 world px). Grid values: `1` = floor, `2` = wall.

`map:is_wall(col, row)` returns true for walls and out-of-bounds.
`map:is_hallway(col, row)` returns true if the floor cell is exactly 1 cell wide in one axis (a corridor cell).
`map:is_doorway(col, row)` returns true if the floor cell is at or adjacent to a hallway cell (a room entrance/exit).
`map:world_to_cell(wx, wy)` and `map:cell_to_world(col, row)` convert between coordinate spaces.

Wall torches listed in a map file are filtered at construction time: any torch whose `{col, row}` is a doorway cell is silently dropped. Place torches away from the hallway-column entrance cell — one column offset from the hallway is enough.

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

## Testing

### Commands

```
love . --headless    # terminal output; exits 0 (all pass) or 1 (any fail)
love . --watch       # same tests rendered live in 3D; press -/= to change sim speed
```

In `--watch` mode each test coroutine drives the simulation frame-by-frame and the raycaster renders every step. Press any key on the summary screen to quit.

### File layout

```
tests/
  runner.lua       Minimal busted-compatible framework — describe / it / assert.*
  stubs.lua        No-op replacements for love.graphics, love.keyboard.isDown, and
                   love.filesystem.getInfo — installed at the top of runner.run()
                   (headless path only; watch mode uses real graphics)
  test_run.lua     Core game scenarios; one it() per scenario
  test_*.lua       Any file starting with test_ is auto-discovered and run by both
                   --headless and --watch. No changes to main.lua needed.
  watch_scene.lua  Scene3D subclass that renders Simulation._current each frame
```

`tests/stubs.lua` installs love.graphics no-ops (including a catch-all metatable for unlisted keys, and stub image tables for any `love.graphics.new*` call) before any game module loads. This lets modules that call `love.graphics.newFont` or `love.graphics.newImage` at require-time be safely loaded in headless mode.

`core/lua/headless_input.lua` is a companion input driver for per-frame edge-trigger tests. It exposes `:press(action)` (sets down+pressed for one frame), `:hold(action)` (down stays, pressed only on first frame), `:release(action)`, `:update()` (clear pressed flags — call before each scene update), `:is_down(action)`, and `:pressed(action)`.

`game/simulation.lua` is the headless run harness. It mirrors RunScene's setup and update loop with no rendering or scene management. The player is driven by `SimInput` (core/lua/sim_input.lua) instead of the keyboard.

```lua
local sim   = Simulation.new(run_config)
local state = sim:step(dt, actions)      -- one tick; returns nil once outcome is set
local final = sim:run_until(pred, opts)  -- loops until pred(state) or max_seconds
```

`actions` keys: `fwd`, `back`, `left`, `right`, `use`, `pickup`.

State snapshot: `outcome`, `tick`, `player.{x,y,angle}`, `monster.{x,y,state}`, `extraction.{active,discovered,time_remaining}`.

### The rule

Every change gets two things: **run the full suite** (`--headless`) to catch regressions, and **add at least one new `it()`** in `tests/test_run.lua` for the new behaviour. Both steps are required — running without adding leaves the new code untested; adding without running misses breakage in existing paths.

### What to add tests for

| Change | Run to catch regressions | New test to add |
|--------|--------------------------|-----------------|
| New trait | All existing trait tests | Positive case (stimulus → correct state within known time). If trigger is conditional (like hearing needing movement), add a negative case too. Mirror smell/hearing/sight tests. |
| New item | Kill + extraction tests | `use_fn` returns the right signal; interaction with extraction or inventory works. For passive items (no `use_fn`), a smoke test confirming no errors over several frames is sufficient. |
| Monster update order | Kill test (ordering is load-bearing) | None required if existing kill test still passes. |
| Extraction logic | All extraction tests (in-zone, returning-to-zone) | None required if all still pass. |
| New map | Smoke-run: `Simulation.new({ map_id = "yourmap", ... }):step(1/60)` | At minimum, that smoke step should not error. Add spawn/extraction coord checks if coords were non-obvious. |
| Player movement / collision | Hearing trait tests (depend on `is_moving`) | Step sequence that injects `fwd` and asserts `player.x/y` changed. |

---

## Adding things

**New item**: add a factory function in `items.lua` following the `make_flashlight` pattern. Give it a `value`. It will auto-appear in spawner if `value ≤ budget`. Wire `use_fn` to return a string signal if RunScene needs to react. Add a test in `tests/test_run.lua`.

**New trait**: add to `traits.lua` with a cost and an `apply(monster)` stub. Implement the behaviour in `monster.lua`'s update loop checking `self.has_<traitname>`. Add a test in `tests/test_run.lua` — see existing trait tests as a template.

**New map**: create `game/world/map_<name>.lua` following the `fill_rect` pattern. Add it to the map picker in `planning_scene.lua` and the loader in `run_scene.lua`. Also add it to `Simulation`'s `load_map` in `game/simulation.lua` so it can be tested headlessly. When placing wall torches, keep them off the hallway-entrance cell — shift one column away from the vertical-hallway column for top-row positions (doorways are automatically filtered but the room will lose its torch if the only position given is a doorway).

**New scene**: subclass `Scene` (or just follow the same metatable pattern). Register it in `main.lua` or transition to it via `scene_ref.manager:switch(...)`.
