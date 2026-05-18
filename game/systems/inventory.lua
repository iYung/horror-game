-- Inventory
-- Five-slot item container. One slot is "active" at a time (shown in HUD, used with F).
-- Items are plain tables from items.new(id) — never share instances between slots.
--
-- Player controls (wired in player.lua):
--   Q / E      → cycle(-1) / cycle(1)
--   1–5        → set active index directly
--   G near item → pick_up; G with nothing nearby → drop
--   F          → use active item (player calls item.use_fn)
--
-- Usage:
--   inv = Inventory.new()
--   inv:pick_up(item)            -- place in first empty slot; returns true/false
--   inv:drop()                   -- remove + return active item
--   inv:swap_with_ground(item)   -- swap active slot with a ground item; returns displaced item
--   inv:active()                 -- item in active slot (may be nil)
--   inv:cycle(dir)               -- dir = 1 or -1, wraps around
--   inv:has_item(id)             -- true if any slot holds that item id
--   inv:remove_item_by_ref(item) -- find and clear a specific item instance (used by burn-out)

local Inventory = {}
Inventory.__index = Inventory

local SLOTS = 5

function Inventory.new()
    local self       = setmetatable({}, Inventory)
    self.slots       = {}
    self._active_idx = 1
    for i = 1, SLOTS do
        self.slots[i] = nil
    end
    return self
end

function Inventory:active()
    return self.slots[self._active_idx]
end

function Inventory:active_index()
    return self._active_idx
end

function Inventory:cycle(dir)
    self._active_idx = ((self._active_idx - 1 + dir) % SLOTS) + 1
end

function Inventory:set_slot(i, item)
    self.slots[i] = item
end

function Inventory:pick_up(item)
    for i = 1, SLOTS do
        if self.slots[i] == nil then
            self.slots[i] = item
            return true
        end
    end
    return false
end

function Inventory:drop()
    local item = self.slots[self._active_idx]
    self.slots[self._active_idx] = nil
    return item
end

function Inventory:swap_with_ground(item)
    local dropped = self.slots[self._active_idx]
    self.slots[self._active_idx] = item
    return dropped
end

function Inventory:has_item(id)
    for i = 1, SLOTS do
        local item = self.slots[i]
        if item and item.id == id then
            return true
        end
    end
    return false
end

function Inventory:remove_active()
    local item = self.slots[self._active_idx]
    self.slots[self._active_idx] = nil
    return item
end

function Inventory:remove_item_by_ref(target)
    for i = 1, SLOTS do
        if self.slots[i] == target then
            self.slots[i] = nil
            return true
        end
    end
    return false
end

return Inventory
