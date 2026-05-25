## Goal

Add an **Adrenaline Shot** item that grants the player a temporary speed boost when activated, followed by a cooldown period during which the item cannot be used again. This gives the player a high-risk escape tool with a meaningful cost window: the item stays in inventory between uses, but mis-timing the boost leaves the player without recourse until the cooldown expires.

---

## Affected files

- `game/data/items.lua` — add `make_adrenaline` factory and `adrenaline` definition entry
- `game/world/item_spawner.lua` — add spawn rule for adrenaline (budget-gated, 1–2 copies)
- `game/entities/player.lua` — read the player's current speed multiplier each frame; apply it to movement
- `game/ui/hud.lua` — display cooldown/boost status in the active slot when adrenaline is held
- `game/scenes/run_scene.lua` — add adrenaline billboard color in `build_sprites`
- `test/run_test.lua` — add smoke test (item held without errors) and an activation test (speed multiplier applies)

---

## What changes

### 1. New item: Adrenaline Shot (`items.lua`)

A new factory function `make_adrenaline` following the `make_flashlight` pattern.

**State fields on the item table:**

| Field | Type | Purpose |
|---|---|---|
| `boosting` | bool | true during the active speed window |
| `on_cooldown` | bool | true after boost ends, until cooldown expires |
| `boost_timer` | Timer\|nil | counts down the boost duration |
| `cooldown_timer` | Timer\|nil | counts down the post-boost cooldown |
| `speed_mult` | number | multiplier read by player each frame (1.0 normally, >1.0 while boosting) |

**Proposed values (tunable):**
- `value = 2` (budget cost; spawns when budget >= 2)
- Boost duration: **5 seconds** — long enough to break contact with the monster over one room
- Speed multiplier during boost: **1.75×** (brings player from `BASE_SPEED` to ~210 px/s, faster than the monster's chase speed of `BASE_SPEED * 0.85 = 102 px/s`)
- Cooldown duration: **20 seconds** — significant cost window; the player can still hold the item but cannot re-activate

**`use_fn` logic:**
- If `boosting` or `on_cooldown`: no-op (cannot re-activate)
- Otherwise: set `boosting = true`, set `speed_mult = 1.75`, start `boost_timer`

**`update(dt)` logic (called by RunScene's item update loop):**
- If `boosting`: tick `boost_timer`; on expiry set `boosting = false`, `on_cooldown = true`, `speed_mult = 1.0`, start `cooldown_timer`
- If `on_cooldown`: tick `cooldown_timer`; on expiry set `on_cooldown = false`
- Item is **never consumed** — it stays in inventory across the whole run (unlike flashlight which burns out)

### 2. Player speed multiplier (`player.lua`)

`Player:update` already computes movement as:
```lua
local dx = math.cos(self.angle) * move * SPEED_GU * dt
```

Change: before computing `dx`/`dy`, read the active item's `speed_mult` field if present:
```lua
local mult = 1.0
local item = self.inventory:active()
if item and item.speed_mult then mult = item.speed_mult end
local dx = math.cos(self.angle) * move * SPEED_GU * mult * dt
```

This is strictly additive — no existing paths change unless the active item sets `speed_mult`.

### 3. HUD status display (`hud.lua`)

When the active item is `adrenaline`, overlay a small status label inside or below the active slot box:
- While `boosting`: amber text `BOOST` (matching the extraction-timer amber)
- While `on_cooldown`: dim red text showing remaining cooldown seconds (e.g. `CD 14s`)
- Otherwise (ready): no extra label — the item name in the slot is sufficient

This reuses the existing `ITEM_FONT` and `COLOR_AMBER` already defined in the file.

### 4. Ground billboard color (`run_scene.lua`)

Add `adrenaline` to the color lookup in `build_sprites`:
```lua
or id == "adrenaline" and {0.2, 1.0, 0.4, 1}   -- bright green
```

### 5. Spawner rule (`item_spawner.lua`)

Following the tracker/compass pattern: spawn **1–2 copies** when `budget >= 2`. Positions drawn from the general walkable pool, excluding reserved cells.

---

## What stays the same

- All existing items (flashlight, flare gun, compass, tracker) are untouched
- Monster behavior, traits, and all state-machine logic are unchanged
- The `use_fn` / `update` calling convention in `player.lua` and `run_scene.lua` is unchanged — adrenaline slots into both without modification
- Inventory system is unchanged; adrenaline occupies a normal slot and is droppable
- The hearing trait's `is_moving()` check on the player is unaffected — boosted movement still counts as moving
- Extraction logic is unaffected

---

## Decisions

1. **Hearing interaction** — No change. The boost does not suppress `is_moving()`. The player just moves faster through the detection zone; the monster can still hear them.
2. **Charges** — Unlimited uses, gated only by the 20 s cooldown. Item is never consumed.
3. **Budget cost** — `value = 2`. Spawns when budget ≥ 2.
4. **HUD cooldown readout** — Overlaid inside the active slot box (small text below the item name). Uses existing `ITEM_FONT` and color constants.
