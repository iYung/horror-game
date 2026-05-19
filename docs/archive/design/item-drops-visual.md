# Design: Item Drops Visual Overhaul

## Goal

Fix five visual and gameplay issues with ground items as they appear in the 3D raycaster view:

1. Items render too high (floating) — fix vertical position
2. Items are too large — reduce billboard size
3. Remove the torch item entirely
4. Each item type renders as a distinct color
5. Add a new "compass" item that points toward the extraction zone, shown as a HUD indicator

---

## Affected files

| File | Why it changes |
|------|---------------|
| `game/data/items.lua` | Remove torch factory and definition; add compass factory |
| `game/world/item_spawner.lua` | Remove torch spawn logic; add compass spawn logic |
| `game/scenes/run_scene.lua` | Fix billboard vertical position; reduce size; assign per-item colors; handle compass signal; adjust fog range table |
| `game/scenes/planning_scene.lua` | No torch-specific logic exists there, but stash display will naturally stop showing torches once removed from data |
| `game/ui/hud.lua` | Add compass bearing indicator drawn each frame when compass is in active inventory slot |
| `core/lua/raycaster.lua` | Expose a `v_offset` field on billboard sprites to fix vertical centering |

---

## What changes

### 1. Fix floating billboard height

**Root cause.** In `core/lua/raycaster.lua` lines 107–108, a sprite's vertical center is pinned to the screen's exact midpoint (`SH / 2`):

```lua
local h_half = math.floor(SH / tz * size / 2)
local sy1    = math.floor(SH / 2 - h_half)
local sy2    = math.floor(SH / 2 + h_half)
```

`SH / 2` is the horizon line — the same vertical center as a wall that fills the full height of the screen. For a billboard smaller than a full wall (`size < 1`), this centering is correct only if the sprite is meant to float at eye level. Floor-placed items should sit on the floor, meaning their top should be at the horizon and their body should extend downward.

**Fix.** Add an optional `v_offset` field to the sprite table. A value of `+0.5` shifts the sprite downward by half a sprite-height (placing the top at the horizon for a floor item). Update `raycaster.lua` to apply it:

```lua
local v_off  = sp.v_offset or 0
local sy1    = math.floor(SH / 2 - h_half + h_half * v_off * 2)
local sy2    = math.floor(SH / 2 + h_half + h_half * v_off * 2)
```

With `v_offset = 1.0` the sprite sits flush on the floor (its center drops by one full half-height below the horizon). A value of `0.5` gives a half-correction. All ground items should use `v_offset = 1.0`; the monster stays at `v_offset = 0` (eye-level).

**Where to set it.** In `run_scene.lua` inside `build_sprites()` (lines 181–189), add `v_offset = 1.0` to each ground item sprite entry. Monster entry at lines 173–178 does not get a `v_offset`.

### 2. Reduce item billboard size

**Current value.** Ground items use `size = 0.4` (lines 183–188 of `run_scene.lua`). The monster uses `size = 0.8`.

**Fix.** Change item `size` to `0.25`. This makes them visually smaller while still being visible at close range. The extraction zone pillar stays at `size = 2.0`.

No raycaster changes needed for this — `size` already scales `h_half` at line 106:
```lua
local h_half = math.floor(SH / tz * size / 2)
```

### 3. Remove the torch item

**Files to change:**

- `game/data/items.lua`
  - Delete the `torch` entry from `definitions` (lines 24–29)
  - Delete `make_torch` function (lines 43–66)
  - Remove `torch = make_torch` from `factories` (line 112)

- `game/world/item_spawner.lua`
  - Delete the entire `if budget >= 1 then` torch spawn block (lines 60–67). Flashlight spawn block (lines 69–75) can remain as-is or be restructured into its own unconditional block when `budget >= 1`.

- `game/scenes/run_scene.lua`
  - In `current_fog_range()` (lines 158–165), remove the `torch` branch:
    ```lua
    if item.id == "torch" and item.active then return 11 end
    ```
    After removal only flashlight and default remain.
  - In `build_sprites()`, the existing color branch `is_flare and {...} or {1, 0.9, 0.3, 1}` currently uses the fallback yellow for torches and flashlights alike. After torch removal, this branch only needs to handle flashlight and compass.

- `game/scenes/planning_scene.lua` — No torch-specific code exists. Stash items are displayed generically by `item.name`; no change required.

- `game/ui/hud.lua` — No torch-specific code exists; no change required.

### 4. Per-item colors

**Current state.** In `build_sprites()` (`run_scene.lua` lines 182–188), all non-flare items share the same yellow `{1, 0.9, 0.3, 1}`. Color is assigned with a single boolean branch on `is_flare`.

**Fix.** Replace the boolean branch with a per-id color lookup table defined at the top of `run_scene.lua`:

```lua
local ITEM_COLORS = {
    flashlight = {0.9, 0.9, 1.0, 1},   -- cool white-blue
    flare_gun  = {1.0, 0.2, 0.8, 1},   -- pink (unchanged)
    compass    = {0.2, 1.0, 0.9, 1},   -- cyan-teal
}
local ITEM_COLOR_DEFAULT = {1, 0.9, 0.3, 1}
```

In `build_sprites()`, replace the `is_flare` branch with:

```lua
local id    = entry.item and entry.item.id or ""
local color = ITEM_COLORS[id] or ITEM_COLOR_DEFAULT
```

### 5. New compass item

**Behaviour.** While the compass is the player's active item, a HUD indicator shows the bearing (in degrees or as an arrow) pointing from the player's current position to the extraction zone center. It has no timer, no `active` toggle, and no side effects — purely informational. It does not affect fog range.

**Spawning.** The compass always spawns exactly once per run (like the flare gun, `value = 0`), guaranteed more than 10 cells from spawn. Add it to `item_spawner.lua` alongside the flare gun spawn logic.

**`game/data/items.lua` additions:**

Add a definition:
```lua
compass = {
    id    = "compass",
    name  = "Compass",
    value = 0,
}
```

Add a factory:
```lua
local function make_compass()
    local self = {}
    for k, v in pairs(definitions.compass) do self[k] = v end
    self.use_fn = function(player, world) end   -- no action on use
    return self
end
```

Register `compass = make_compass` in `factories`.

**`game/world/item_spawner.lua` additions.**

After the flare gun spawn block, add a compass spawn block using the same flare pool logic (or a shared far-from-spawn pool), ensuring the compass lands more than 10 cells from spawn and is not placed on the same cell as the flare gun.

**`game/ui/hud.lua` changes.**

`HUD.new` already receives `inventory` and `extraction`. No new constructor arguments are needed; `extraction._zone` holds `x`, `y` for the target position, and the player's current position can be computed from `player:centre()`.

To give HUD access to the player, change `HUD.new(inventory, extraction)` to `HUD.new(inventory, extraction, player)` and store `self.player = player`. Update the call in `run_scene.lua` `on_enter` accordingly.

In `HUD:draw()`, add a compass panel drawn when the active item is the compass:

```lua
local active = self.inventory:active()
if active and active.id == "compass" then
    local pc   = self.player:centre()
    local ez   = self.extraction._zone
    local dx   = ez.x - pc.x
    local dy   = ez.y - pc.y
    local bearing = math.atan2(dy, dx)   -- absolute world bearing in radians

    -- Convert to relative bearing from player facing angle
    local facing   = self.player.angle
    local relative = bearing - facing
    -- Normalize to -pi..pi
    relative = (relative + math.pi) % (math.pi * 2) - math.pi

    -- Draw arrow or degree readout in top-center of screen
    -- Arrow: pick a Unicode arrow glyph or draw a line indicator
    local deg = math.floor(math.deg(relative))
    local label = "COMPASS  " .. (deg >= 0 and ("+" .. deg) or tostring(deg)) .. "°"
    -- Draw at screen top-center
    love.graphics.setFont(EXTRACT_FONT)
    local tw = EXTRACT_FONT:getWidth(label)
    love.graphics.setColor(0.2, 1.0, 0.9, 1)
    love.graphics.print(label, (1280 - tw) / 2, 8)
end
```

The `player.angle` field is already public (set each frame in `player.lua`). The relative bearing of 0° means the extraction is directly ahead; negative means turn left, positive means turn right.

**`game/scenes/run_scene.lua` changes for compass.**

No signal interception needed (compass `use_fn` returns nothing). The only additions are:
- Include compass in `ITEM_COLORS` (see section 4).
- Pass `self.player` into `HUD.new` so HUD can read position and facing angle.

---

## What stays the same

- The raycaster's wall rendering, z-buffer, and fog attenuation logic are unchanged.
- The `size` field convention and sprite sort order (far-to-near) are unchanged.
- The flare gun item, its `use_fn`, and the `wrap_flare_gun` interception in `run_scene.lua` are unchanged.
- The flashlight item, its timer, `active`/`on` flags, and fog range override (`return 14`) are unchanged.
- The monster billboard (`size = 0.8`, red color, no `v_offset`) is unchanged.
- The extraction zone pillar (`size = 2.0`, pulsing green) is unchanged.
- `CameraShake`, `Pathfinder`, `Inventory`, and all scene transition logic are unchanged.
- `PlanningScene` layout, budget rolling, and trait rolling are unchanged.
- Both map files (`map_forest.lua`, `map_hospital.lua`) are unchanged.

---

## Open questions

1. **`v_offset` exact value.** `1.0` places the sprite center one full `h_half` below the horizon, which should put the bottom of the sprite at approximately the floor line at close range. At very close distances (small `tz`) the sprite will be very tall and may still clip oddly. Test whether `0.75` or `0.9` looks better in practice before committing to `1.0`.

2. **Compass HUD — relative vs. absolute bearing.** The design above shows a degree offset from the player's current facing direction. An alternative is a fixed-north minimap needle or a screen-edge pointer. Relative bearing (`+/-` degrees) requires the least new rendering code and reuses existing fonts/colors.

3. **Compass billboard color in fog.** Cyan (`{0.2, 1.0, 0.9, 1}`) is visually distinct from pink (flare) and blue-white (flashlight), but may be hard to distinguish from the ceiling/floor colors at long range. Consider a brighter or warmer alternative if playtesting reveals it blends in.

4. **Compass spawn guarantee.** If both flare gun and compass use the same far-from-spawn pool and the map is very small (e.g., budget 0 with few walkable cells), the pool might not have two distinct cells. The implementation should handle this gracefully — either allow the compass to spawn closer to spawn, or skip spawning the compass rather than crashing.

5. **Stash interaction with compass.** If the player extracts with a compass, it enters the stash and can be brought back next run as a loadout item. This is fine and consistent with the existing stash design — no special handling needed — but worth confirming it is the desired behavior.

6. **Torch removal and fog range.** After torch removal, `current_fog_range()` in `run_scene.lua` only needs two branches (flashlight on → 14, default → 8). The `if item.id == "torch"` line at line 163 should be deleted entirely rather than left as dead code.
