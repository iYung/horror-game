## Goal

Enable programmatic testing of run-level game logic (monster AI, extraction flow,
trait behavior, kill detection) without a window, running inside Love2D, using
busted as the test framework.

## Affected files

| File | New / Modified |
|------|----------------|
| `conf.lua` | New |
| `main.lua` | Modified |
| `core/lua/sim_input.lua` | New |
| `game/entities/player.lua` | Modified — accept optional `input` override |
| `game/simulation.lua` | New |
| `test/run_test.lua` | New |

## What changes

### 1. `conf.lua` — disable window in headless mode

Love2D reads `conf.lua` before loading any game code. We detect the `--headless`
CLI argument here and set `t.window = false` and `t.audio.enable = false` so Love2D
starts with no GPU context or audio thread.

```lua
-- conf.lua
function love.conf(t)
    for _, v in ipairs(arg or {}) do
        if v == "--headless" then
            t.window      = false
            t.audio.enable = false
            break
        end
    end
    t.window.title = "NIGHTFALL"
end
```

Invocation: `love . -- --headless`

### 2. `main.lua` — headless branch

When `--headless` is set, `main.lua` wires `love.load` as a test runner entry
point: busted executes the test suite, then `love.event.quit(0)` exits cleanly.
The normal game boot path is untouched.

```lua
-- main.lua (added branch)
local headless = false
for _, v in ipairs(arg or {}) do
    if v == "--headless" then headless = true break end
end

if headless then
    function love.load()
        require("busted.runner")({ "--output=utfTerminal", "test/" })
        love.event.quit(0)
    end
else
    -- existing love.load, love.update, love.draw …
end
```

### 3. `core/lua/sim_input.lua` — scriptable input

`Input` calls `love.keyboard.isDown` every frame. `SimInput` has the same
interface (`update`, `is_down`, `pressed`) but reads from an injected actions
table set by the caller before each step. No love.keyboard calls.

```lua
SimInput.new()              -- create with all actions false
SimInput:inject(actions)    -- set {fwd=true, left=true, …} for next update
SimInput:update()           -- copies injected → _down/_pressed; clears inject
SimInput:is_down(action)    -- same as Input
SimInput:pressed(action)    -- same as Input
```

`inject` is idempotent: calling it multiple times before `update` uses the last
call. Not calling it before `update` leaves all actions false.

### 4. `game/entities/player.lua` — optional input override

`Player.new(x, y, map)` gains an optional fourth parameter:

```lua
function Player.new(x, y, map, input_override)
    …
    self.input = input_override or Input.new({ fwd={"w"}, … })
    …
end
```

No other logic changes. RunScene passes nothing and gets the keyboard-backed Input
as before. Simulation passes a SimInput instance.

### 5. `game/simulation.lua` — headless run wrapper

`Simulation` mirrors RunScene's `on_enter` + `update` setup but skips everything
render-related (no raycaster, no Drawer, no HUD, no Scene3D). It exposes:

```lua
Simulation.new(run_config)
    -- Wires: map, CameraShake (still needed by monster), SimInput, Player,
    -- Monster, ItemSpawner, Extraction. No raycaster / Drawer / HUD.
    -- run_config is the same RunConfig table PlanningScene produces.

Simulation:step(dt, actions)
    -- Advances by dt seconds with optional actions table (same keys as SimInput).
    -- Returns a state snapshot (see below) or nil if already finished.

Simulation:state()
    -- Returns current state snapshot without advancing time.

Simulation:run_until(pred, opts)
    -- Steps in opts.dt increments (default 1/60) until pred(state) returns true
    -- or opts.max_seconds (default 120) is exceeded.
    -- Returns final state snapshot.
```

State snapshot shape:
```lua
{
    outcome    = nil | "death" | "extracted" | "failed",
    tick       = <number>,           -- total seconds simulated
    player     = { x, y, angle },
    monster    = { x, y, state },    -- state: wander/alerted/chase/search
    extraction = { active=bool, discovered=bool, time_remaining=number },
}
```

`on_kill` and extraction callbacks mutate `self._outcome` instead of switching
scenes.

### 6. `test/run_test.lua` — busted test file

Example structure (not exhaustive — implementer adds cases):

```lua
describe("run simulation", function()
    it("monster kills player when within 48px", function() … end)
    it("player survives a run with no traits", function() … end)
    describe("traits", function()
        it("sight: monster chases on LOS", function() … end)
        it("smell: monster alerted without LOS", function() … end)
    end)
end)
```

## What stays the same

- All existing game logic: `monster.lua`, `player.lua`, `extraction.lua`, all
  traits, item behavior — zero changes.
- RunScene — untouched. Headless mode is additive.
- Rendering path (raycaster, HUD, Drawer, Scene3D) — never imported by Simulation.
- Scene flow (Planning → TraitReveal → Run → Result) — not exercised by tests.
  Simulation is a direct thin harness, not going through the scene graph.
- SaveState / stash logic — not relevant at run simulation level; not included.

## Open questions

None — confirmed with user:
- Runtime: Love2D, no window (`love . -- --headless`)
- Test framework: busted (BDD-style)
- Test scope: run simulation level
