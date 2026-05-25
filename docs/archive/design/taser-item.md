## Goal

Add a **Taser** item that lets the player stun the monster for a short window when used at close range. This gives the player a single-charge panic tool to break contact during a chase — high risk (must be within melee range to fire), high reward (full monster freeze). The item is consumed on a successful stun and does nothing when the monster is out of range, so skilled use is required to get value from it.

---

## Affected files

- `game/data/items.lua` — add `make_taser` factory and `taser` definition entry
- `game/entities/monster.lua` — add `stunned` state, `stun_timer`, and `stun(duration)` method; gate the kill check and state machine on `stunned`
- `game/world/item_spawner.lua` — add spawn rule for taser (budget-gated, 1–2 copies)
- `game/scenes/run_scene.lua` — add taser billboard color in `build_sprites`; wire `"stun"` signal from `use_fn` to call `monster:stun()`
- `game/simulation.lua` — no structural changes needed; the `use` action already drives `use_fn` through `player:update`, and `monster:stun()` operates on the same monster reference
- `tests/test_run.lua` — add two new tests: stun applies when monster is in range, and use is a no-op when monster is out of range

---

## What changes

### 1. New item: Taser (`items.lua`)

A new factory function `make_taser` following the `make_flare_gun` pattern (single-use, consumed after firing).

**Definition entry:**
```lua
taser = { id = "taser", name = "Taser", value = 5 }
```

**State fields on the item table:**

| Field | Type | Purpose |
|---|---|---|
| `used` | bool | true after the taser has been fired; prevents double-use |

**`use_fn(player, world)` logic:**
- If `self.used`: no-op, return `nil`
- Otherwise: set `self.used = true`, return `"stun"`
- `use_fn` does **not** check range itself — RunScene performs the range check before acting on the signal, mirroring the flare gun / extraction pattern
- The item is **always consumed** on use regardless of range — there is no charge refund on a miss

**No `update` function** — the item has no timer of its own; it is simply consumed.

**Item value:** `value = 2` — same budget cost as adrenaline. Spawns when `budget >= 2`.

---

### 2. Monster stun state (`monster.lua`)

#### New fields (set in `Monster.new`)

```lua
self.stunned      = false
self.stun_timer   = nil    -- Timer instance while stunned, nil otherwise
```

#### New method `Monster:stun(duration)`

```lua
function Monster:stun(duration)
    self.stunned    = true
    self.stun_timer = Timer.new(duration)
end
```

Calling `stun()` while already stunned resets the timer (stun is not stackable in this design, but the call should be safe).

#### Stun duration: **4 seconds**

Four seconds is long enough to break LOS during a chase and duck into a different room, but short enough that mis-timing the approach is punished. At `CHASE_SPEED = 102 px/s` the monster would have covered ~408 px (≈12.75 cells) in that window — enough for a meaningful escape.

#### Integration in `Monster:update`

At the **top** of `Monster:update`, before the kill check and before the trait/state-machine blocks:

```lua
-- Burn down stun timer; freeze everything while stunned
if self.stunned then
    if self.stun_timer and self.stun_timer:update(dt) then
        self.stunned    = false
        self.stun_timer = nil
    end
    return   -- skip kill check, trait sensors, and movement this frame
end
```

Placing the guard before the kill check at `d_px < 48` means the monster cannot kill the player while stunned even if they are standing on top of it. This is intentional: the player takes the risk to close distance and fire, so they get a safe window to retreat.

After the stun expires the monster resumes from whatever state it was in when stunned — no state reset. If it was chasing, it continues to chase; if wandering, it continues wandering. The existing `last_known_pos` is preserved, so an alerted or chasing monster picks back up immediately.

---

### 3. RunScene signal handling (`run_scene.lua`)

`use_fn` returns `"stun"` when fired. RunScene must intercept this signal, check range, and call `monster:stun()` if the monster is close enough. This follows the same interception pattern used for the flare gun:

**Stun range: 96 pixels (3 cells)**

96 px is twice the kill distance (48 px), so the player must close to uncomfortable proximity to land the stun — but not quite melee range. At that distance the monster is visually close and the tension is real.

Add a `wrap_taser` helper in `run_scene.lua` (modeled after `wrap_flare_gun`):

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

**Always consumed on use:** The taser is consumed the moment F is pressed, regardless of whether the monster is in range. If out of range, the item disappears with no stun effect.

Apply `wrap_taser` in `RunScene:on_enter` after spawning ground items and loadout, symmetrically with how `maybe_wrap` is called for flare guns:

```lua
local function maybe_wrap_taser(item)
    if item and item.id == "taser" then
        wrap_taser(item, self.monster, self.player)
    end
end
for _, entry in ipairs(self.ground_items) do maybe_wrap_taser(entry.item) end
for i = 1, 5 do maybe_wrap_taser(self.player.inventory.slots[i]) end

self.player.on_pickup = function(entry)
    -- existing body...
    maybe_wrap_taser(entry.item)
end
```

---

### 4. Ground billboard color (`run_scene.lua`)

Add `taser` to the color lookup in `build_sprites`:

```lua
or id == "taser" and {0.3, 0.8, 1.0, 1}   -- electric cyan
```

Cyan is distinct from all existing item colors (yellow flashlight, pink flare gun, blue compass, orange tracker, green adrenaline).

---

### 5. Spawner rule (`item_spawner.lua`)

Spawn **1–2 copies** when `budget >= 5`, drawn from the general walkable pool after flashlights, trackers, and adrenaline have reserved their cells:

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

---

### 6. Tests (`tests/test_run.lua`)

**Test A — stun applies when monster is in range:**
- Create sim with no traits, `budget = 5`, `loadout_item = Items.new("taser")`
- Teleport monster to 64 px from player centre (well within the 96 px stun range)
- Null out `monster.on_kill` so the proximity does not end the run
- Inject `use = true` for one tick
- Assert `sim.monster.stunned == true`

**Test B — taser is consumed but no stun when monster is out of range:**
- Same setup, but place monster 200 px away (outside 96 px range)
- Inject `use = true`
- Assert `sim.monster.stunned == false` and item is consumed (`item.used == true`)

---

## What stays the same

- All existing items (flashlight, flare gun, compass, tracker, adrenaline) are untouched
- The monster state machine's four states (`wander`, `alerted`, `chase`, `search`) and all trait logic are unchanged; the stun guard is prepended before them, not woven into them
- The kill-distance check at `d_px < 48` is unchanged; it is simply skipped while stunned
- `Simulation` requires no changes — `player:update` drives `use_fn` through the existing `use` injection, and `monster:stun()` operates on the same object reference already present in the sim
- `ItemSpawner` picking logic, reservation system, and flare gun guarantee are untouched
- Inventory, pickup, and drop mechanics are unaffected
- HUD requires no new code — taser has no persistent state to display (it is consumed after one use)
- The `wrap_flare_gun` pattern and the `maybe_wrap` closure in `on_enter` are unchanged in behavior; `maybe_wrap_taser` is added alongside them

---

## Open questions

None. The following ambiguities were resolved as design decisions:

1. **Stun range** — Set to **96 px (3 cells)**. Twice the kill distance so the player must close to real danger, but not all the way to point-blank. The alternative (2 cells / 64 px) was considered too punishing given the first-person perspective makes precise distance judgment difficult.

2. **Stun duration** — Set to **4 seconds**. Long enough to exit a room and break LOS; short enough to not trivially negate any trait. The smell trait fires every 2.5 s, so a 4 s stun does not fully neutralize it (the timer continues to accumulate during the stun and will fire shortly after the monster resumes).

3. **Charge refund on miss** — On a miss the `used` flag is reset. Silent failure (consuming the charge when the monster is out of range) would be frustrating in first-person where distance is hard to judge; a refund makes the item feel fair. A visual/audio cue (not in scope here) would reinforce the miss, but the refund alone avoids the most frustrating failure mode.

4. **Single charge, item consumed** — The taser follows the flare gun model: one use, then gone. This makes the decision to fire meaningful and prevents the stun from being a repeatable panic button.

5. **State after stun expires** — Monster resumes its pre-stun state rather than resetting to wander. A chase monster resuming chase after stun is correct — the player just bought time to get away, not a full reset.

6. **Monster can still be killed during stun** — The kill check being skipped during stun is intentional; the player took the risk of closing to stun range, so they should be safe while the stun is active. It also avoids an edge case where the monster kills the player on the same frame the stun fires.

7. **Budget cost** — `value = 5`. High cost reflects the power of a full monster freeze; at budget 7 the player can only pair it with one cheap item (flashlight or tracker). Spawns when `budget >= 5`.

8. **Always consumed on use** — The taser is consumed the moment F is pressed, regardless of range. A miss wastes the item. This makes firing decisions genuinely costly and rewards reading the monster's position carefully.
