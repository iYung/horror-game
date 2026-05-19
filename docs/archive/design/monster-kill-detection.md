## Goal

Fix the monster kill detection so the player dies when the monster reaches close range, regardless of whether the player is moving or standing still.

## Affected files

- `game/entities/monster.lua` — contains the kill check and the coordinate space mismatch (lines 161–165, 252–254)
- `game/entities/player.lua` — defines `centre()` (lines 67–69) and the coordinate system

## What changes

### Root cause: coordinate space mismatch in the kill check

The kill distance check in `monster.lua` compares monster pixel coordinates against the value returned by `player:centre()`, but `player:centre()` returns the **top-left corner** of the player's cell, not the player's actual centre.

**Monster position** (`self.x`, `self.y`) — pixel space, no offset. Monster is spawned with raw pixel values from `map.extraction.x / y` (run_scene.lua line 58) and moves entirely in pixel space.

**Player position** (`player.x`, `player.y`) — 1-indexed grid units. A player standing in the center of spawn cell A1 (grid unit ≈ 1.5, 1.5) has a pixel position of roughly (16, 16).

**`player:centre()`** (player.lua lines 67–69):
```lua
return { x = (self.x - 1) * CELL, y = (self.y - 1) * CELL }
```
This formula computes `(1.5 - 1) * 32 = 16` px — which is the **top-left corner of the cell the player is in**, not the player's visual/physical centre. The player's true pixel centre is `(self.x - 1) * CELL` only when `self.x` is exactly 1.0 (integer). For a player at grid unit 1.5 (centered in a cell), the formula gives 16 px, which is the left edge of the 32 px cell. The true center of that cell is 16 px from the left edge, so numerically it happens to be correct in that specific case — but the name `centre()` is misleading and the formula is only accidentally correct for cell-centers.

More critically: the kill distance threshold is `48` pixels (`d_px < 48` at monster.lua line 252), which equals 1.5 cells. However, the **kill check only runs when the monster is in the `"chase"` state** (lines 249–254). The monster only enters `"chase"` state via the `sight` trait LOS check or the `hearing` trait — which means:

- A monster **without the `sight` or `hearing` traits** can walk directly into the player while in `"wander"` or `"alerted"` state and **never trigger the kill**, because the kill check at line 252–254 is inside the `elseif self.state == "chase" then` branch only.
- A monster with no traits wanders using A* pathfinding toward random cells, may pass through the player's position, and never checks kill distance because the state never becomes `"chase"`.

### The actual bug

The kill distance check (`d_px < 48` → `self.on_kill()`) is **only evaluated inside the `"chase"` state block** (monster.lua lines 249–254). It is completely absent from the `"wander"`, `"alerted"`, and `"search"` state blocks.

When a monster without `sight` trait wanders directly toward a standing-still player:
1. The monster is in `"wander"` state, following an A* path.
2. `hearing` only triggers if `player:is_moving()` is true — a standing-still player returns `false` from `is_moving()` (player.lua line 87: `self._moved = move ~= 0`).
3. `smell` triggers every 2.5 seconds and sets `"alerted"` state, which moves toward `last_known_pos` via A*; but the kill check is also absent from `"alerted"`.
4. So the monster walks into (or through) the player without ever firing `on_kill`.

Even with a monster that has `sight` trait: if the LOS raycast somehow misses (e.g., player and monster in same cell — `los_clear` returns `true` when `d == 0`, so this is fine), chase is triggered. But for a traitless monster, no chase is ever triggered by a standing player.

**Secondary issue — coordinate formula in `player:centre()`:**

The formula `(self.x - 1) * CELL` converts a 1-indexed grid-unit position to the top-left pixel corner of the cell. For a player at grid position 1.5 GU, this gives `0.5 * 32 = 16` px. The cell runs from 0 to 32 px, so pixel 16 is the true center — this is numerically correct. However, the formula is only correct because the player spawns offset by +0.5 GU into the cell (run_scene.lua line 63: `spawn_gx = map.spawn.x / CELL + 1.5`). If the player ever starts at an integer GU (e.g., `1.0`), `centre()` would return `0` px (top-left corner) instead of `16` px (cell center). This is a latent correctness issue but not the primary cause of the kill failure in the reported bug.

## What stays the same

- The `on_kill` callback wiring in `run_scene.lua` (lines 78–85) is correct and does not need to change.
- The `"chase"` state kill check at line 252 (`d_px < 48`) is the right threshold and should be kept.
- The coordinate conversion in `player:centre()` is effectively correct for current usage (player always starts at +0.5 GU offset); the formula should be reviewed for robustness but the primary fix is elsewhere.
- The `dist()` helper function (lines 34–38) is correct.
- Monster movement, trait logic, and state transitions are all correct.

## What changes

**Fix: move the kill check outside the state machine, so it fires every frame regardless of state.**

In `monster.lua`'s `update` function, the distance `d_px` is already computed at the top of every frame (line 165: `local d_px = dist(mx, my, px, py)`). The kill check should be lifted out of the `"chase"` branch and placed at the top of `update`, before the state machine, so it fires unconditionally every frame:

```lua
-- At the top of Monster:update, after computing d_px (around line 165):
if d_px < 48 then
    self.on_kill()
    return
end
```

The `return` prevents the state machine from running after `on_kill` fires (since `_dead` flag in RunScene makes subsequent frames no-ops, but the return is defensive).

The existing kill check inside the `"chase"` block (lines 252–254) should be removed to avoid redundancy.

**Optional secondary fix: correct `player:centre()` formula to be robust.**

Change player.lua line 68 from:
```lua
return { x = (self.x - 1) * CELL, y = (self.y - 1) * CELL }
```
to:
```lua
return { x = (self.x - 0.5) * CELL, y = (self.y - 0.5) * CELL }
```
This returns the true pixel center of the player's current sub-cell position regardless of the fractional GU offset, eliminating the latent off-by-half-cell issue. Note: this changes what all callers receive (extraction, item pickup, monster distance) — all checks use radius-based comparisons so a 16 px shift in the reported center may affect those thresholds. This fix should be verified against extraction radius and item pickup radius (`NEARBY_R = 48` in player.lua line 23).

## Open questions

1. Should the kill check fire in all states, or only in `"chase"` and `"alerted"`? Letting the monster kill in `"wander"` is realistic (accidental encounters are lethal) but changes the feel of traitless monsters. The safest fix is all-states.
2. Does the `player:centre()` formula change affect extraction? `Extraction:in_zone` uses pixel distance from `player:centre()` to `map.extraction.x/y`. A 16 px shift in reported player position could push a player at the edge of the zone in or out. Needs a test with the current zone radius.
3. Is the `return` after `on_kill()` the right guard, or should it check `self._dead` directly? RunScene already guards via `if self._dead or self._extracted then return end` at the top of `update`, so repeated `on_kill` calls on the same frame are blocked by the `if not self._dead then` check in the callback. The `return` in monster update is still good defensive practice.
