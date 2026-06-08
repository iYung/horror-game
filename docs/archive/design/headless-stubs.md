# Headless Testing Improvements

## Goal

Port two testing utilities from `../wip-3d` to make the horror-game test suite more robust and ergonomic:

1. **`tests/stubs.lua`** — installs no-op replacements for `love.graphics` (and `love.keyboard.isDown`) before any game module loads in `--headless` mode, so accidental rendering calls fail silently rather than crashing with a nil-index error.

2. **`core/lua/headless_input.lua`** — a more ergonomic scriptable input class with `press()` / `hold()` / `release()` semantics, ported from wip-3d's `HeadlessInput`. Complements (does not replace) the existing `SimInput`.

---

## Affected files

| File | Change |
|------|--------|
| `tests/stubs.lua` | New file — no-op love.graphics table with catch-all metatable |
| `core/lua/headless_input.lua` | New file — ported HeadlessInput |
| `tests/runner.lua` | `require("tests/stubs")` before running any test files |

`conf.lua`, `main.lua`, `game/simulation.lua`, and existing tests are unchanged.

---

## What changes

### `tests/stubs.lua`

Direct port of wip-3d's `lua/headless/stubs.lua`, trimmed to what horror-game needs.

Installs `love.graphics` as a table of explicit no-ops for every method the raycaster and scene code call (`setColor`, `rectangle`, `line`, `draw`, `setScissor`, `push`, `pop`, `translate`, `scale`, `setShader`, `setBlendMode`, `print`, `printf`, `clear`, `setDefaultFilter`). A catch-all `__index` metatable returns a no-op for any unlisted key, except `new*` names return a factory that produces a stub image (`getWidth`/`getHeight`/`getDimensions`/`setFilter`).

Also stubs:
- `love.keyboard.isDown` → always returns `false`
- `love.filesystem.getInfo` → always returns `nil` (prevents asset loading from finding files)
- `love.graphics.getDimensions` → returns `1280, 720`
- `love.graphics.newShader` → returns `{ send = noop }` (safe for any future shader construction at module load time)

**Why this matters now:** the existing test suite works without stubs because `Simulation` never calls `love.graphics`. But as the codebase grows — especially after the sprite changes in `wip-3d-ports` where RunScene loads images — requiring `run_scene` directly in a test would crash. Stubs make the floor safe.

### `tests/runner.lua`

Add one line at the top of the test collection loop, before any `require` of test files:

```lua
require("tests/stubs")   -- install no-op love.graphics before test modules load
```

This is the only change to the runner.

### `core/lua/headless_input.lua`

Ported from wip-3d's `lua/headless/input.lua` with no changes to behaviour. Provides a cleaner API than `SimInput` for tests that need fine-grained per-frame control:

| Method | What it does |
|--------|-------------|
| `HeadlessInput.new()` | Creates instance with empty state |
| `:press(action)` | Queues a single-frame rising edge (down + pressed, auto-released next frame) |
| `:hold(action)` | Holds action down indefinitely (down but not pressed after first frame) |
| `:release(action)` | Clears action from all state immediately |
| `:update()` | Advances one frame; call before scene:update() |
| `:is_down(action)` | True while held |
| `:pressed(action)` | True only on the frame the action first went down |

**Relationship to `SimInput`:** `SimInput` stays in place — `Simulation` uses it via `sim:step(dt, actions)` batch injection, which suits AI playtesting and scenario scripts. `HeadlessInput` is for future tests that drive RunScene or PlanningScene directly, where per-frame edge semantics matter (e.g. testing that pressing `F` once uses an item exactly once rather than continuously).

Neither class replaces the other. They live side by side.

---

## What stays the same

- `conf.lua` — still disables `t.window` and `t.audio.enable` in `--headless` mode. Stubs layer on top of this; they don't change how LÖVE starts.
- `game/simulation.lua` and all existing tests — no changes required. Tests that currently pass will continue to pass.
- `core/lua/sim_input.lua` — unchanged; still used by `Simulation`.
- `--watch` mode — stubs are only loaded in the `--headless` path (inside `runner.lua`); watch mode is unaffected.

---

## Open questions

None.
