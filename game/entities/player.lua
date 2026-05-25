-- Player
-- First-person player. Stores position in 1-indexed grid units to match the raycaster
-- coordinate system. WASD: W/S move forward/back along facing angle, A/D turn.
-- centre() converts back to pixel space so existing systems (extraction, monster
-- distance checks, item pickup) continue to work unchanged.
--
-- BASE_SPEED (px/s) is exported so monster.lua can scale from it as before.
--
-- Callbacks (set by RunScene):
--   on_use(item)    — called when F is pressed with an active item
--   on_pickup(item) — called when an item is picked up from the ground
--   on_drop(item)   — called when an item is dropped

local Input     = require("core/lua/input")
local Inventory = require("game/systems/inventory")
local Map       = require("game/world/map")

local BASE_SPEED = 120
local CELL       = Map.CELL
local SPEED_GU   = BASE_SPEED / CELL   -- grid units per second (≈ 3.75)
local TURN_SPEED = 2.2                 -- radians per second
local MARGIN     = 0.25               -- collision radius in grid units
local NEARBY_R   = 48                 -- pixel radius for nearby-item check (1.5 cells)

local Player = {}
Player.__index    = Player
Player.BASE_SPEED = BASE_SPEED

local function can_move(map, x, y)
    return not (map:is_wall(math.floor(x - MARGIN), math.floor(y - MARGIN)) or
                map:is_wall(math.floor(x + MARGIN), math.floor(y - MARGIN)) or
                map:is_wall(math.floor(x - MARGIN), math.floor(y + MARGIN)) or
                map:is_wall(math.floor(x + MARGIN), math.floor(y + MARGIN)))
end

function Player.new(x, y, map, input_override)
    local self     = setmetatable({}, Player)
    self.x         = x       -- grid unit position (1-indexed)
    self.y         = y
    self.angle     = 0       -- facing angle in radians (0 = right)
    self.map       = map
    self.inventory = Inventory.new()
    self._moved    = false
    self.on_use    = nil
    self.on_drop   = nil
    self.on_pickup = nil
    self.input     = input_override or Input.new({
        fwd   = {"w"},
        back  = {"s"},
        left  = {"a"},
        right = {"d"},
        slot1 = {"1"},
        slot2 = {"2"},
        slot3 = {"3"},
        slot4 = {"4"},
        slot5 = {"5"},
        prev  = {"q"},
        next  = {"e"},
        use   = {"f"},
        grab  = {"g"},
    })
    return self
end

-- Returns player centre in pixel space — used by extraction, monster, item pickup.
-- Converts grid unit position to pixel centre: pixel = (gu - 0.5) * CELL.
-- Using -0.5 (not -1) gives the true sub-cell centre for any fractional GU value.
-- The old formula (-1) was numerically correct only because the player always spawns
-- at a +0.5 GU offset; this version is correct for any position.
-- Net effect on callers: reported pixel position shifts by +16 px in x and y.
-- Extraction radius (64 px) and item pickup radius (NEARBY_R = 48 px) are both
-- large enough that this shift does not break zone detection.
function Player:centre()
    return { x = (self.x - 0.5) * CELL, y = (self.y - 0.5) * CELL }
end

function Player:cell()
    return { col = math.floor(self.x), row = math.floor(self.y) }
end

function Player:is_moving()
    return self._moved
end

function Player:update(dt, ground_items)
    self.input:update()

    local move = (self.input:is_down("fwd")   and 1 or 0)
               - (self.input:is_down("back")  and 1 or 0)
    local turn = (self.input:is_down("right") and 1 or 0)
               - (self.input:is_down("left")  and 1 or 0)

    self._moved = move ~= 0

    if turn ~= 0 then
        self.angle = self.angle + turn * TURN_SPEED * dt
    end

    if move ~= 0 then
        local speed_scale = 1.0
        for i = 1, 5 do
            local item = self.inventory.slots[i]
            if item and item.speed_mult and item.speed_mult > speed_scale then
                speed_scale = item.speed_mult
            end
        end
        local dx = math.cos(self.angle) * move * SPEED_GU * dt * speed_scale
        local dy = math.sin(self.angle) * move * SPEED_GU * dt * speed_scale
        if can_move(self.map, self.x + dx, self.y)  then self.x = self.x + dx end
        if can_move(self.map, self.x,      self.y + dy) then self.y = self.y + dy end
    end

    if self.input:pressed("prev")  then self.inventory:cycle(-1) end
    if self.input:pressed("next")  then self.inventory:cycle(1)  end
    if self.input:pressed("slot1") then self.inventory._active_idx = 1 end
    if self.input:pressed("slot2") then self.inventory._active_idx = 2 end
    if self.input:pressed("slot3") then self.inventory._active_idx = 3 end
    if self.input:pressed("slot4") then self.inventory._active_idx = 4 end
    if self.input:pressed("slot5") then self.inventory._active_idx = 5 end

    if self.input:pressed("use") then
        local item = self.inventory:active()
        if item and item.use_fn then
            item.use_fn(self)
        elseif self.on_use then
            self.on_use(self)
        end
    end

    if self.input:pressed("grab") then
        local nearest = self:nearby_item(ground_items or {})
        if nearest then
            local picked = self.inventory:pick_up(nearest.item)
            if picked and self.on_pickup then
                self.on_pickup(nearest)
            end
        else
            local dropped = self.inventory:drop()
            if dropped and self.on_drop then
                self.on_drop(dropped)
            end
        end
    end
end

function Player:active_item()
    return self.inventory:active()
end

function Player:nearby_item(ground_items)
    local c      = self:centre()
    local best   = nil
    local best_d = NEARBY_R + 1
    for _, entry in ipairs(ground_items) do
        local d = math.sqrt((entry.x - c.x)^2 + (entry.y - c.y)^2)
        if d <= NEARBY_R and d < best_d then
            best   = entry
            best_d = d
        end
    end
    return best
end

function Player:draw()
    -- No 2D sprite in first-person mode; player is rendered via raycaster viewpoint
end

return Player
