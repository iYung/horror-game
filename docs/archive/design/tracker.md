## Goal

Add a new passive item called "Tracker" that behaves identically to the Compass but points toward the monster instead of the extraction zone, and costs 1 budget point instead of 3.

When the Tracker is the player's active item, the HUD draws a **red arrow** that rotates to always point at the monster's current position in world space, using the same directional-arrow rendering the Compass uses for the extraction zone. The item is passive (no `use_fn`). It spawns on the ground when `budget >= 1`.

---

## Affected files

| File | Why |
|------|-----|
| `game/data/items.lua` | Add `tracker` definition and `make_tracker` factory; register in `factories` table |
| `game/ui/hud.lua` | Add tracker arrow rendering block; HUD needs a reference to the monster |
| `game/scenes/run_scene.lua` | Pass monster to `HUD.new(...)` so the HUD can read monster position |
| `game/world/item_spawner.lua` | Spawn 1–2 trackers when `budget >= 1` |
| `test/run_test.lua` | Add smoke test confirming tracker can be held without errors over several frames |

---

## What changes

### `game/data/items.lua`

Add a `tracker` entry in `definitions`:

```lua
tracker = { id = "tracker", name = "Tracker", value = 1 },
```

Add a `make_tracker` factory (mirrors `make_compass` — returns a plain copy of the definition with no `use_fn`):

```lua
local function make_tracker()
    local self = {}
    for k, v in pairs(definitions.tracker) do self[k] = v end
    return self
end
```

Register it in `factories`:

```lua
tracker = make_tracker,
```

Update the module comment at the top to document the new item.

### `game/ui/hud.lua`

`HUD.new` currently accepts `(inventory, extraction, player)`. Extend the signature to also accept `monster`:

```lua
function HUD.new(inventory, extraction, player, monster)
    ...
    self.monster = monster
    ...
end
```

In `HUD:draw()`, after the existing Compass arrow block, add a Tracker arrow block:

```lua
-- Tracker arrow: shown when player holds the tracker
if self.player and self.monster then
    local item = self.player.inventory:active()
    if item and item.id == "tracker" then
        local pc  = self.player:centre()
        local dx  = self.monster.x - pc.x
        local dy  = self.monster.y - pc.y
        local world_angle    = math.atan2(dy, dx)
        local relative_angle = world_angle - self.player.angle
        love.graphics.push()
        love.graphics.translate(640, 680)
        love.graphics.rotate(relative_angle)
        love.graphics.setColor(1, 0.15, 0.15, 0.85)   -- red, matching monster billboard color
        love.graphics.polygon("fill", 0, -18, -10, 10, 10, 10)
        love.graphics.pop()
    end
end
```

The monster's position (`monster.x`, `monster.y`) is already in pixel space, matching `player:centre()` output. No coordinate conversion is needed.

### `game/scenes/run_scene.lua`

Update the `HUD.new(...)` call to pass `self.monster`:

```lua
self.hud = HUD.new(self.player.inventory, self.extraction, self.player, self.monster)
```

No other changes needed in this file.

### `game/world/item_spawner.lua`

Add a tracker spawn block alongside the existing flashlight and compass blocks. Trackers cost 1 point, so they spawn when `budget >= 1`:

```lua
if budget >= 1 then
    local tr_count = math.random(1, 2)
    local tr_cells = pick_random(walkable, tr_count, reserved)
    for _, cell in ipairs(tr_cells) do
        local wx, wy = cell_centre(cell.col, cell.row)
        table.insert(ground, { x = wx, y = wy, item = Items.new("tracker") })
        reserved[cell.col * 1000 + cell.row] = true
    end
end
```

Place this block after the flashlight block and before the compass block. The tracker uses no distinct color in the existing billboard sprite list in `run_scene.lua`, so it will fall through to the default yellow color `{1, 0.9, 0.3, 1}`. If a distinct ground color is desired (e.g., orange-red to hint at its purpose), the `build_sprites` color dispatch in `run_scene.lua` can be extended with:

```lua
or id == "tracker" and {1, 0.4, 0.1, 1}
```

This is a minor polish decision — the Checklist Agent should include it.

### `test/run_test.lua`

Add a smoke test mirroring the existing compass test:

```lua
it("tracker item can be held without errors", function()
    local run_config = make_config({
        budget         = 1,
        map_id         = "forest",
        monster_traits = {},
        loadout_item   = Items.new("tracker"),
    })
    local sim = Simulation.new(run_config)

    local state
    for _ = 1, 10 do
        state = sim:step(1 / 60)
    end

    assert.is_not_nil(state)
end)
```

Note: `Simulation` does not exercise `HUD:draw()` (it's headless), so the arrow rendering is not directly tested. The smoke test confirms the item instantiates correctly and no runtime errors occur during normal update ticks.

---

## What stays the same

- The Compass item and its white extraction-zone arrow are unchanged.
- All other items (flashlight, flare gun) are unchanged.
- The monster's position representation (pixel space, `monster.x`/`monster.y`) is unchanged.
- The spawner's flare gun placement logic is unchanged.
- `HUD.new`'s first three arguments keep their existing meaning and order; `monster` is appended as a fourth argument, so all existing call sites that omit it (e.g., tests) remain valid because Lua treats missing arguments as `nil` and the tracker block guards with `self.monster`.
- The `Simulation` headless harness does not instantiate `HUD`, so no changes are needed in `game/simulation.lua`.
- The `RunScene` draw order (3D raycaster pass then 2D HUD overlay) is unchanged.

---

## Open questions

None. The feature is a direct structural parallel to the Compass. All coordinate systems, rendering patterns, and spawn patterns have clear precedents in the existing code.
