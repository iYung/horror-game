# lua/core

Engine-level classes with no game-specific knowledge. Safe to reuse across projects.

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

A self-contained game state. Owns a Drawer and a Camera.

- `Scene.new()` — creates `self.drawer` and `self.camera`
- `update(dt)` / `draw()` — override in subclasses
- `on_enter()` — called when this scene becomes active
- `on_exit()` — calls `drawer:clear()` by default

`draw()` wraps `drawer:draw()` inside `camera:attach()`/`camera:detach()`.

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
