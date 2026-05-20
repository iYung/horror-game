# lua/core

Engine-level classes with no game-specific knowledge. Safe to reuse across projects.

---

## Quick start — new 3D scene

```lua
local Scene3D  = require("core/lua/scene_3d")
local Map      = require("core/lua/map")
local Player3D = require("game/player_3d")   -- move/turn with WASD

local MyScene = setmetatable({}, { __index = Scene3D })
MyScene.__index = MyScene

local GRID = {
    { 1,1,1,1,1 },
    { 1,0,0,0,1 },
    { 1,0,0,0,1 },
    { 1,1,1,1,1 },
}

function MyScene.new()  return setmetatable(Scene3D.new(), MyScene) end
function MyScene:on_enter()
    self.map    = Map.new(GRID)
    self.player = Player3D.new(2.5, 2.5, 0)   -- grid position, angle in radians
end
function MyScene:update(dt)  self.player:update(dt) end
function MyScene:draw()
    self.raycaster:draw(self.map, self.player.x, self.player.y, self.player.angle)
end

return MyScene
```

Player3D (`game/player_3d.lua`) binds W/S to forward/back and A/D to turn. Swap it for your own if you need collision, mouse-look, etc.

**Coordinate system:** positions are in grid units (float). `(1.5, 1.5)` is the centre of cell `(1,1)`. Angle `0` faces right (+x); `π/2` faces down (+y), matching Love2D's screen axes.

---

## Quick start — new 2D scene

```lua
local Scene2D = require("core/lua/scene_2d")

local MyScene = setmetatable({}, { __index = Scene2D })
MyScene.__index = MyScene

function MyScene.new()  return setmetatable(Scene2D.new(), MyScene) end
function MyScene:on_enter()
    -- self.drawer and self.camera are ready to use
end
function MyScene:update(dt) end
function MyScene:draw()
    Scene2D.draw(self)   -- camera-wrapped drawer pass
    -- HUD draws go here (outside camera transform)
end
function MyScene:on_exit()  Scene2D.on_exit(self) end  -- clears drawer

return MyScene
```

---

## Sprite

A drawable unit at a world position.

| Property | Type | Notes |
|----------|------|-------|
| `x`, `y` | number | World position (top-left) |
| `width`, `height` | number | Dimensions in pixels |
| `scale_x`, `scale_y` | number | Scale factors (default `1`) |
| `visible` | bool | Skips draw when false |
| `color` | `{r,g,b,a}` | Tint; defaults to white `{1,1,1,1}` |
| `image` | Love2D image | If set, draws image scaled to `width × height`; if nil, draws a filled rectangle |
| `shader` | Love2D shader | Applied only during `draw()`, then cleared |

`Sprite.new(x, y, w, h)` — `draw()` — `update(dt)` (no-op hook)

`draw()` scales the image to fill exactly `width × height`, so the image's native pixel size doesn't need to match. `color` is applied as a tint in both image and rectangle modes.

---

## SpriteSet

A named collection of Sprites with one active at a time.

- `SpriteSet.new()`
- `add(name, sprite)` — register a sprite
- `set(name)` — switch the active sprite
- `draw()` — copies `x`/`y` to the active sprite, then calls its `draw()`
- `update(dt)` — delegates to the active sprite
- `_active()` — returns the current Sprite

Implements the same `draw()`/`update(dt)` interface as Sprite, so it's a drop-in anywhere a Sprite is expected. `color`, `scale_x`, `scale_y` are per-sprite properties — set them on each Sprite after `add()`.

---

## Drawer

Renders all registered drawables each frame in priority order.

- `Drawer.new()`
- `add(drawable, priority)` — lower priority = drawn first (behind); sorted on add
- `draw()` — calls `drawable:draw()` on each entry in order
- `clear()` — removes all entries

Any object with a `draw()` method can be registered, not just Sprites.

---

## Camera

Controls what part of the world is visible. Logical resolution: **1280 × 720**.

- `Camera.new(x, y)`
- `attach()` / `detach()` — push/pop the camera transform around a draw call
- `follow(target, lerp)` — smooth-track `target.x/y`; `lerp` 0 = instant, 1 = no movement
- `zoom` — scale factor (default `1.0`)

---

## Scene

Pure lifecycle base class. No rendering state — subclass or use `Scene2D` / `Scene3D`.

- `Scene.new()`
- `update(dt)` / `draw()` / `on_enter()` / `on_exit()` — no-op stubs, override in subclasses

---

## Scene2D

Inherits `Scene`. Owns a `Drawer` and a `Camera` for 2D rendering.

- `Scene2D.new()` — creates `self.drawer` and `self.camera`
- `draw()` — wraps `drawer:draw()` inside `camera:attach()`/`camera:detach()`
- `on_exit()` — calls `drawer:clear()`

Call `Scene2D.draw(self)` and `Scene2D.on_exit(self)` from subclass overrides to keep the default behaviour.

---

## Scene3D

Inherits `Scene`. Owns a `Raycaster` for first-person 3D rendering.

- `Scene3D.new()` — creates `self.raycaster`
- Subclass provides a `Map` and player state; call `self.raycaster:draw(map, px, py, angle)` in `draw()`

---

## SceneManager

Holds the active scene and drives the game loop.

- `SceneManager.new()`
- `switch(scene)` — calls `on_exit()` on the old scene, `on_enter()` on the new one
- `update(dt)` / `draw()` — delegate to `current`

---

## Timer

A delta-time accumulator that fires when an interval elapses.

- `Timer.new(interval)` — create a timer with the given interval in seconds
- `update(dt)` — advance the timer; returns `true` when the interval elapses (keeps remainder for loop use)
- `reset(interval?)` — restart the accumulator; optionally change the interval

Use as an interval/metronome (loop) by acting on each `true` return. Use as a countdown by calling `reset()` after it fires. The remainder is preserved across each tick, so intervals don't drift.

---

## Input

Action-based keyboard polling. Call `update()` once per frame before reading input.

- `Input.new(key_map)` — `key_map` is `{ action = { keys... } }`, e.g. `{ jump = {"space", "w"} }`
- `update()` — sample keyboard state; call once per frame
- `is_down(action)` — true while any bound key is held
- `pressed(action)` — true only on the frame the action was first pressed

---

## SimInput

Drop-in replacement for `Input` with an identical public interface, for use in simulations and tests. Pass it as the fourth argument to `Player.new` to override keyboard input.

- `SimInput.new()`
- `inject(actions)` — set `{ action = true/false }` for the next `update()` call
- `update()` — snapshots injected state into `_down` / `_pressed` (rising-edge detection), then clears the inject table
- `is_down(action)` — true while action was injected `true` in the last `update()`
- `pressed(action)` — true only on the frame the action first went true

Any action not present in the injected table defaults to `false`. Actions released between ticks (absent from the next `inject`) are automatically treated as not held.

---

## Map

A 2D grid of integer cells used for raycaster levels.

- `Map.new(grid)` — `grid` is a 1-indexed table of rows, each a table of integers (0 = empty, non-zero = wall)
- `is_wall(x, y)` — true if cell at column `x`, row `y` is non-zero
- `cell(x, y)` — raw cell value (0 if out of bounds)
- `width()` / `height()` — grid dimensions

---

## Raycaster

DDA-based first-person column renderer with z-buffered billboard sprites and distance fog.

- `Raycaster.new()`
- `draw(map, px, py, angle, opts)` — render one frame

`px`/`py` are the player's position in 1-indexed grid units (float); `angle` is facing direction in radians.

`opts` fields (all optional):

| Field | Default | Meaning |
|-------|---------|---------|
| `fov` | `π/3` | Horizontal FOV in radians |
| `lights` | `{}` | List of point lights — walls and sprites outside all light radii render black |
| `sprites` | `{}` | List of billboard sprites (see below) |

Each light: `{ x, y, radius, intensity }` where `x`/`y` are 1-indexed grid units, `radius` is in cells, and `intensity` (0–1) scales brightness. Multiple lights accumulate and clamp to 1. With no lights the scene is pitch black.

Each sprite: `{ x, y, size=1, color={r,g,b,a} }` where `x`/`y` are grid units and `size` scales height relative to wall height at the same distance. Sprites are lit by the same point-light list and invisible outside all light radii.

Internally builds a per-column z-buffer during the wall pass; sprites are drawn back-to-front and clipped against it. Resets `love.graphics` colour to white after drawing.
