## Monster Kill Detection Checklist

- [x] Task A — `game/entities/monster.lua` lines 161–165 — Add an unconditional kill check at the top of `Monster:update`, immediately after `d_px` is computed (line 165). Insert:
  ```lua
  if d_px < 48 then
      self.on_kill()
      return
  end
  ```
  Place this block after line 165 (`local d_px = dist(mx, my, px, py)`) and before the `step_timer` block that begins at line 167. The `return` prevents the state machine from running after `on_kill` fires.

- [x] Task B — `game/entities/monster.lua` lines 249–254 — Remove the now-redundant kill check from inside the `"chase"` state block. Delete these three lines:
  ```lua
  if d_px < 48 then
      self.on_kill()
  end
  ```
  After Task A the kill fires every frame regardless of state; keeping a second copy in the chase branch is redundant and misleading.

- [x] Task C — `game/entities/player.lua` line 68 — Fix `player:centre()` to return the true pixel centre of the player's sub-cell position. Change:
  ```lua
  return { x = (self.x - 1) * CELL, y = (self.y - 1) * CELL }
  ```
  to:
  ```lua
  return { x = (self.x - 0.5) * CELL, y = (self.y - 0.5) * CELL }
  ```
  This makes the formula correct for any fractional grid-unit position, not just the +0.5 GU spawn offset. After changing this, verify that the extraction zone radius (`map.extraction.radius`) and item pickup radius (`NEARBY_R = 48`, player.lua line 23) still produce sensible results given the 16 px shift in reported player centre; both use radius-based comparisons so the change only matters at the boundary of those radii.
