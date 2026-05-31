# Settings Menu

## Goal

Pressing Escape opens a pause/settings overlay. From PlanningScene it shows an opaque background; from RunScene it shows a semi-transparent overlay and pauses the game. The menu contains three items: "Fullscreen / Window", "Exit Settings", and "Leave Game".

## Affected files

| File | Change |
|------|--------|
| `game/settings_state.lua` | New — owns `fullscreen` bool and `toggle_fullscreen()` |
| `game/scenes/settings_menu.lua` | New — the overlay object |
| `main.lua` | Wire settings_menu lifecycle: keypressed routing, pause-on-open, draw on top |
| `game/scenes/planning_scene.lua` | Add `esc_opens_settings = true`, `esc_settings_opaque = true` |
| `game/scenes/run_scene.lua` | Add `esc_opens_settings = true`; remove existing Escape → PlanningScene handler |
| `assets/menu_btn.png` | Copy from `../wip/assets/` |
| `assets/menu_btn_selected.png` | Copy from `../wip/assets/` |
| `assets/settings_background.png` | Copy from `../wip/assets/` |
| `tests/test_settings_state.lua` | New — unit tests for SettingsState |
| `tests/test_settings_menu.lua` | New — unit tests for SettingsMenu |

## What changes

### `game/settings_state.lua` (new)

```lua
SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
    return setmetatable({ fullscreen = false }, SettingsState)
end

function SettingsState:toggle_fullscreen()
    self.fullscreen = not self.fullscreen
    love.window.setFullscreen(self.fullscreen)
end

return SettingsState
```

### `game/scenes/settings_menu.lua` (new)

Plain Lua table (not a Scene subclass — no Camera/Drawer needed). Items:
```
1. Fullscreen / Window    (label reads "Window" when fullscreen, "Fullscreen" when windowed)
2. Exit Settings
3. Leave Game
```

- Navigation: up/down arrows, edge-wrap, edge-triggered via `_prev_*` flags
- Confirm: `E` or `F` or `return`/`space`
- Close: `Escape`
- `open(opaque)` — sets `is_open = true`, snapshots current key state to prevent bleed-through
- `draw()` — opaque path draws `settings_background.png`; transparent path draws a `0,0,0,0.55` rect. Then draws `menu_btn.png` / `menu_btn_selected.png` per row with text.
- `update(dt)` — reads `love.keyboard.isDown` directly, same pattern as the rest of the codebase

Layout constants match 1280×720 (same as `../wip`): `BTN_W=300`, `BTN_H=54`, centred horizontally, rows spaced 74 px apart.

`keypressed(key)` is a no-op (reserved for future capture flows; returns `false`).

### `main.lua`

In `love.load()` (normal game path only, inside the `else` branch):
```lua
local SettingsState = require("game/settings_state")
local SettingsMenu  = require("game/scenes/settings_menu")
local ss = SettingsState.new()
settings_menu = SettingsMenu.new(ss)
```

In `love.update(dt)` (normal path):
```lua
if settings_menu and settings_menu.is_open then
    settings_menu:update(dt)
else
    manager:update(dt)
end
```

In `love.draw()` (normal path):
```lua
manager:draw()
if settings_menu and settings_menu.is_open then
    settings_menu:draw()
end
```

In `love.keypressed(key)` (normal path):
```lua
-- Give the open menu first crack at keypressed
if settings_menu and settings_menu.is_open then
    if settings_menu:keypressed(key) then return end
end
-- Escape: open/close settings if current scene opts in
if key == "escape" then
    local cur = manager.current
    if settings_menu and cur and cur.esc_opens_settings then
        if settings_menu.is_open then
            settings_menu:close()
        else
            settings_menu:open(cur.esc_settings_opaque or false)
        end
        return
    end
end
-- Fall through to scene keypressed
if manager.current and manager.current.keypressed then
    manager.current:keypressed(key)
end
```

### `game/scenes/planning_scene.lua`

Set on the instance in `PlanningScene.new()`:
```lua
self.esc_opens_settings = true
self.esc_settings_opaque = true
```

No other changes — PlanningScene has no existing Escape handler.

### `game/scenes/run_scene.lua`

Set `self.esc_opens_settings = true` in `RunScene.new()` / `on_enter`.

Remove the existing Escape handler:
```lua
-- REMOVE this block:
if key == "escape" then
    local manager = require("game/scene_ref").manager
    local PlanningScene = require("game/scenes/planning_scene")
    manager:switch(PlanningScene.new(self.save_state))
end
```

## What stays the same

- Scene system, SceneManager, all other scenes and their logic
- `core/lua/input.lua` action-map system — settings menu reads raw keyboard directly
- No Escape handling in TraitRevealScene or ResultScene (they have no Escape handler today and aren't adding one)
- All existing tests; the new test files are additive
- `--headless` and `--watch` paths in `main.lua` are untouched (settings_menu is only created in the normal `else` branch)

## Open questions

None — all resolved.
- Volume sliders: skipped (no Sound module yet). ✓
- Keybinds sub-screen: skipped. ✓
- Assets: copy from `../wip/assets/`. ✓
- PlanningScene access: Escape key, opaque background. ✓
