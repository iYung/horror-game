# Compass Item — Design

## Goal

Add a **Compass** item that helps the player navigate to the extraction zone. While the compass is the active inventory slot, a directional arrow is drawn on the HUD pointing toward the extraction zone (relative to player facing). No button press required — it is purely passive.

---

## Affected files

| File | Role |
|------|------|
| `game/data/items.lua` | Add `compass` definition and `make_compass` factory |
| `game/ui/hud.lua` | Accept player ref; draw compass arrow when active item is compass |
| `game/scenes/run_scene.lua` | Pass `self.player` as third arg to `HUD.new` |
| `test/run_test.lua` | Add compass integration test |

---

## What changes

### 1. `game/data/items.lua`

New entry in `definitions`:
```lua
compass = { id = "compass", name = "Compass", value = 3 }
```

New factory `make_compass` — no `use_fn`, no `update`, no state. Returns a plain table copied from the definition plus an `is_compass = true` sentinel to make HUD detection unambiguous.

Register in `factories` table.

### 2. `game/ui/hud.lua`

`HUD.new` gains a third parameter: `player`. Stored as `self.player`.

In `HUD:draw()`, after the slot bar and extraction indicator:

```
if active item is compass then
    compute dx, dy from player:centre() to extraction._zone.{x,y}
    world_angle = atan2(dy, dx)
    relative_angle = world_angle - player.angle
    draw a small arrow (rotated triangle) at a fixed screen position,
    pointing at relative_angle
end
```

Arrow placement: center-bottom of screen (e.g. x=640, y=680). Drawn as a filled triangle using `love.graphics.polygon`, rotated with a `love.graphics.push/pop` + `love.graphics.translate/rotate`. Color: white with slight transparency.

`extraction._zone` is accessed directly (Lua has no private enforcement); extraction zone coords are stable for the lifetime of a run.

### 3. `game/scenes/run_scene.lua`

Single-line change: `HUD.new(self.player.inventory, self.extraction)` → `HUD.new(self.player.inventory, self.extraction, self.player)`.

### 4. `test/run_test.lua`

One new `it()`: create a run with a compass in slot 1, step for a few frames, assert no errors (smoke test). The compass has no behavioral side-effects so the test scope is narrow — confirming instantiation, inventory slot, and HUD draw path don't crash.

---

## What stays the same

- Compass does **not** interact with `extraction.discovered` — the pulsing "▼ EXTRACT" text is unrelated and unchanged.
- Compass has no `use_fn`, so pressing `F` does nothing while it is active.
- Compass does not affect fog range, monster behavior, or any other system.
- Spawner behavior unchanged — compass spawns as a ground item if `budget >= 3`, same as all other items.
- The flare gun wrapping logic in `run_scene.lua` is untouched; compass needs no analogous wrapping.

---

## Open questions

None — all resolved before writing this doc:
- **Passive vs. active**: passive (always on while held).
- **Budget cost**: 3.
- **Visual**: single rotating arrow triangle.
