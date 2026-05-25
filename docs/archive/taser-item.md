## Taser Item Checklist

- [x] Task 1 — `game/data/items.lua` — Add `taser` definition and `make_taser` factory function

  Add the definition entry to the `definitions` table (after `adrenaline`):
  ```lua
  taser = { id = "taser", name = "Taser", value = 5 },
  ```

  Add a `make_taser` factory function (after `make_adrenaline`, before the `factories` table), following the `make_flare_gun` pattern:
  ```lua
  local function make_taser()
      local self = {}
      for k, v in pairs(definitions.taser) do self[k] = v end
      self.used = false

      self.use_fn = function(player, world)
          if self.used then return nil end
          self.used = true
          return "stun"
      end

      return self
  end
  ```
  Register it in the `factories` table:
  ```lua
  taser = make_taser,
  ```

- [x] Task 2 — `game/entities/monster.lua` — Add `stunned` / `stun_timer` fields and `Monster:stun()` method; prepend stun guard to `Monster:update`

  **Depends on nothing — can run in parallel with Task 1.**

  In `Monster.new` (after `self.step_timer = Timer.new(0.5)`, around line 80), add two new fields:
  ```lua
  self.stunned    = false
  self.stun_timer = nil
  ```

  Add a new method after `Monster.new` closes and before `Monster:update` (after line 103):
  ```lua
  function Monster:stun(duration)
      self.stunned    = true
      self.stun_timer = Timer.new(duration)
  end
  ```

  At the very top of `Monster:update` (before line 162's `local mx, my = self.x, self.y`), add the stun guard:
  ```lua
  if self.stunned then
      if self.stun_timer and self.stun_timer:update(dt) then
          self.stunned    = false
          self.stun_timer = nil
      end
      return
  end
  ```
  This block must come before the `d_px < 48` kill check so the monster cannot kill the player while stunned.

- [x] Task 3 — `game/world/item_spawner.lua` — Add taser spawn rule (budget >= 5, 1–2 copies)

  **Depends on Task 1 (requires `Items.new("taser")` to exist).**

  Add the taser block after the existing `budget >= 2` adrenaline block (after line 100, before the flare gun pool block at line 103):
  ```lua
  if budget >= 5 then
      local ta_count = math.random(1, 2)
      local ta_cells = pick_random(walkable, ta_count, reserved)
      for _, cell in ipairs(ta_cells) do
          local wx, wy = cell_centre(cell.col, cell.row)
          table.insert(ground, { x = wx, y = wy, item = Items.new("taser") })
          reserved[cell.col * 1000 + cell.row] = true
      end
  end
  ```
  Follow the exact same pattern as the adrenaline block above it. The variable names `ta_count` and `ta_cells` mirror the conventions `ad_count`/`ad_cells` and `tr_count`/`tr_cells` already in the file.

- [x] Task 4 — `game/scenes/run_scene.lua` — Add `wrap_taser` helper, wire it in `on_enter`, and add `taser` color to `build_sprites`

  **Depends on Tasks 1 and 2 (requires `items.new("taser")` and `monster:stun()` to exist).**

  **Part A — `wrap_taser` helper.** Add after the existing `wrap_flare_gun` function (after line 35, before `RunScene.new`):
  ```lua
  local function wrap_taser(item, monster, player)
      if item._taser_wrapped then return end
      item._taser_wrapped = true
      local original_use = item.use_fn
      item.use_fn = function(p, world)
          local result = original_use(p, world)
          if result == "stun" then
              local pc   = p:centre()
              local dx   = monster.x - pc.x
              local dy   = monster.y - pc.y
              local d_px = math.sqrt(dx * dx + dy * dy)
              if d_px <= 96 then
                  monster:stun(4)
              end
              -- Always consumed: no refund if out of range
          end
      end
  end
  ```

  **Part B — wire in `on_enter`.** In `RunScene:on_enter`, after the `maybe_wrap` closure and its two loops (lines 88–94), add a parallel `maybe_wrap_taser` closure and apply it to the same two collections, plus hook it into `on_pickup`. The existing `on_pickup` callback body (lines 99–106) must be extended:
  ```lua
  local monster_ref = self.monster
  local player_ref  = self.player
  local function maybe_wrap_taser(item)
      if item and item.id == "taser" then
          wrap_taser(item, monster_ref, player_ref)
      end
  end
  for _, entry in ipairs(self.ground_items) do maybe_wrap_taser(entry.item) end
  for i = 1, 5 do maybe_wrap_taser(self.player.inventory.slots[i]) end
  ```
  Then extend the existing `self.player.on_pickup` callback (currently line 98–106) to also call `maybe_wrap_taser`:
  ```lua
  self.player.on_pickup = function(entry)
      for i = #self.ground_items, 1, -1 do
          if self.ground_items[i] == entry then
              table.remove(self.ground_items, i)
              break
          end
      end
      maybe_wrap(entry.item)
      maybe_wrap_taser(entry.item)
  end
  ```

  **Part C — billboard color in `build_sprites`.** In `build_sprites` (around line 196), extend the color chain to include `taser` before the final fallback. The current chain ends with:
  ```lua
  or id == "adrenaline" and {0.2, 1.0, 0.4, 1}
  or                       {1, 0.9, 0.3, 1}
  ```
  Change it to:
  ```lua
  or id == "adrenaline" and {0.2, 1.0, 0.4, 1}
  or id == "taser"      and {0.3, 0.8, 1.0, 1}
  or                        {1, 0.9, 0.3, 1}
  ```
  Cyan `{0.3, 0.8, 1.0, 1}` is distinct from all existing item colors.

- [x] Task 5 — `tests/test_run.lua` — Add two new `it()` tests for taser behavior

  **Depends on Tasks 1, 2, and 4 (requires full taser wiring to test end-to-end).**

  Add both tests inside the existing `describe("Simulation", function() … end)` block, after the last `it()` (after line 188, before the closing `end)`).

  **Test A — stun applies when monster is in range (≤ 96 px):**
  ```lua
  it("taser stuns monster when within range", function()
      local sim = Simulation.new(make_config({
          budget       = 5,
          loadout_item = Items.new("taser"),
      }))

      -- Place monster 64 px from player centre (192,160) — well inside 96 px stun range
      sim.monster.x      = 192 + 64
      sim.monster.y      = 160
      sim.monster.on_kill = nil  -- prevent kill from ending the run

      local state = sim:step(1 / 60, { use = true })

      assert.is_true(sim.monster.stunned)
  end)
  ```

  **Test B — taser is consumed but no stun when monster is out of range (> 96 px):**
  ```lua
  it("taser is consumed but does not stun when monster is out of range", function()
      local taser = Items.new("taser")
      local sim   = Simulation.new(make_config({
          budget       = 5,
          loadout_item = taser,
      }))

      -- Place monster 200 px away — outside 96 px stun range
      sim.monster.x      = 192 + 200
      sim.monster.y      = 160
      sim.monster.on_kill = nil

      sim:step(1 / 60, { use = true })

      assert.is_false(sim.monster.stunned)
      assert.is_true(taser.used)
  end)
  ```

  Note on `taser.used` access: the `loadout_item` reference passed to `make_config` is the same table that ends up in the inventory slot after `Simulation.new` calls `inventory:set_slot(1, run_config.loadout_item)`. Reading `taser.used` directly on the local reference is valid because Lua tables are passed by reference.
