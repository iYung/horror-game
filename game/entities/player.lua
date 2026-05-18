-- Player
-- The player character. 16×16 green sprite with WASD movement, wall-sliding collision,
-- and a 5-slot inventory. Facing direction is the last non-zero movement vector —
-- used by the FOV system to orient the vision cone.
--
-- BASE_SPEED is exported so monster.lua can read it and match/scale from the same value.
--
-- Callbacks (set by RunScene):
--   on_use(item)   — called when F is pressed with an active item
--   on_pickup(item)— called when an item is picked up from the ground
--   on_drop(item)  — called when an item is dropped
--
-- Key bindings:
--   WASD          movement
--   Q / E         cycle inventory slots
--   1–5           jump to slot
--   F             use active item / interact
--   G             pick up nearby ground item, or drop active item if nothing nearby

local Sprite    = require("core/lua/sprite")
local Input     = require("core/lua/input")
local Inventory = require("game/systems/inventory")

local BASE_SPEED = 120
local HALF      = 8
local COLOR     = {0.2, 0.8, 0.4, 1}
local NEARBY_R  = 32

local Player = {}
Player.__index  = Player
Player.BASE_SPEED = BASE_SPEED

function Player.new(x, y, map)
    local self       = setmetatable({}, Player)
    self.sprite      = Sprite.new(x, y, 16, 16)
    self.sprite.color = COLOR
    self.map         = map
    self.inventory   = Inventory.new()
    self.facing      = {dx = 1, dy = 0}
    self._moved      = false
    self.on_use      = nil
    self.on_drop     = nil
    self.on_pickup   = nil
    self.input       = Input.new({
        up     = {"w"},
        down   = {"s"},
        left   = {"a"},
        right  = {"d"},
        slot1  = {"1"},
        slot2  = {"2"},
        slot3  = {"3"},
        slot4  = {"4"},
        slot5  = {"5"},
        prev   = {"q"},
        next   = {"e"},
        use    = {"f"},
        grab   = {"g"},
    })
    return self
end

function Player:centre()
    return {x = self.sprite.x + HALF, y = self.sprite.y + HALF}
end

function Player:cell()
    return self.map:world_to_cell(self.sprite.x + HALF, self.sprite.y + HALF)
end

function Player:is_moving()
    return self._moved
end

local function corner_blocked(map, px, py)
    local corners = {
        {px - HALF, py - HALF},
        {px + HALF - 1, py - HALF},
        {px - HALF, py + HALF - 1},
        {px + HALF - 1, py + HALF - 1},
    }
    for _, c in ipairs(corners) do
        local col, row = map:world_to_cell(c[1], c[2])
        if map:is_wall(col, row) then return true end
    end
    return false
end

function Player:update(dt, ground_items)
    self.input:update()

    local dx, dy = 0, 0
    if self.input:is_down("left")  then dx = dx - 1 end
    if self.input:is_down("right") then dx = dx + 1 end
    if self.input:is_down("up")    then dy = dy - 1 end
    if self.input:is_down("down")  then dy = dy + 1 end

    local moved = dx ~= 0 or dy ~= 0
    self._moved = moved

    if moved then
        local len = math.sqrt(dx * dx + dy * dy)
        local ndx = dx / len
        local ndy = dy / len
        self.facing.dx = ndx
        self.facing.dy = ndy

        local s   = self.sprite
        local nx  = s.x + ndx * BASE_SPEED * dt
        local ny  = s.y + ndy * BASE_SPEED * dt

        if not corner_blocked(self.map, nx, s.y) then
            s.x = nx
        end
        if not corner_blocked(self.map, s.x, ny) then
            s.y = ny
        end
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
    local c    = self:centre()
    local best = nil
    local best_d = NEARBY_R + 1
    for _, entry in ipairs(ground_items) do
        local ex, ey = entry.x, entry.y
        local d = math.sqrt((ex - c.x)^2 + (ey - c.y)^2)
        if d <= NEARBY_R and d < best_d then
            best   = entry
            best_d = d
        end
    end
    return best
end

function Player:draw()
    self.sprite:draw()

    local c   = self:centre()
    local fdx = self.facing.dx
    local fdy = self.facing.dy
    local ox  = fdx * (HALF + 4)
    local oy  = fdy * (HALF + 4)
    local aw, ah = 4, 8
    local ax  = c.x + ox - aw / 2
    local ay  = c.y + oy - ah / 2

    love.graphics.setColor(COLOR)
    love.graphics.rectangle("fill", ax, ay, aw, ah)
    love.graphics.setColor(1, 1, 1, 1)
end

return Player
