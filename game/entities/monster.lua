-- Monster
-- AI enemy with a four-state machine and up to four optional traits.
-- Kills the player on contact (< 16 px). Walks through walls — wall collision is
-- intentionally disabled; the pathfinder is only used to pick wander destinations.
--
-- States:
--   wander  — random walk via A*, WANDER_SPEED
--   alerted — moves toward last_known_pos, slightly faster than wander
--   chase   — straight-line pursuit of live player position, CHASE_SPEED
--   search  — paces near last_known_pos for 4 s, then back to wander
--
-- Traits (applied from traits_list passed to new()):
--   sight   — LOS raycast 12 cells; instant chase; also triggers on active flashlight glow
--   speed   — adds SPEED_BOOST to all movement speeds
--   smell   — every 2.5 s unconditionally updates last_known_pos (global, no range)
--   hearing — triggers alerted when player moves within 8 cells
--
-- Step timer fires every 0.5 s and calls shake:trigger() based on distance buckets.
-- on_kill callback must be set by RunScene before gameplay starts.

local Timer      = require("core/lua/timer")
local Map        = require("game/world/map")
local Player     = require("game/entities/player")

local CELL          = Map.CELL
local BASE_SPEED    = Player.BASE_SPEED
local WANDER_SPEED  = BASE_SPEED * 0.35
local CHASE_SPEED   = BASE_SPEED * 0.85
local SPEED_BOOST   = BASE_SPEED * 0.25

local Monster = {}
Monster.__index = Monster

local function dist(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function los_clear(map, mx, my, px, py)
    local dx   = px - mx
    local dy   = py - my
    local d    = math.sqrt(dx * dx + dy * dy)
    if d == 0 then return true end
    local sx   = dx / d
    local sy   = dy / d
    local step = 0
    while step < d do
        local wx = mx + sx * step
        local wy = my + sy * step
        local col, row = map:world_to_cell(wx, wy)
        if map:is_wall(col, row) then return false end
        step = step + 1
    end
    return true
end

function Monster.new(x, y, map, shake, traits_list)
    local self            = setmetatable({}, Monster)
    self.x                = x
    self.y                = y
    self.map              = map
    self.shake            = shake
    self.visible          = true
    self.on_kill          = function() end

    self.state            = "wander"
    self.path             = nil
    self.last_known_pos   = nil
    self.search_timer     = 0

    self.has_speed        = false
    self.has_sight        = false
    self.has_smell        = false
    self.has_hearing      = false

    self.sight_lost_timer = 0

    self.smell_timer      = Timer.new(2.5)
    self.step_timer       = Timer.new(0.5)
    self.stunned    = false
    self.stun_timer = nil

    local walkable        = map:walkable_cells()
    self._walkable        = walkable

    local pathfinder      = require("game/systems/pathfinder").new(map)
    self._pathfinder      = pathfinder

    for _, id in ipairs(traits_list or {}) do
        if id == "speed"   then self.has_speed   = true end
        if id == "sight"   then self.has_sight   = true end
        if id == "smell"   then self.has_smell   = true end
        if id == "hearing" then self.has_hearing = true end
    end

    -- Generate initial wander path immediately so the monster moves from frame 1
    local init_cell = walkable[love.math.random(1, #walkable)]
    if init_cell then
        local mc, mr = map:world_to_cell(x, y)
        self.path = pathfinder:find(mc, mr, init_cell.col, init_cell.row)
    end

    return self
end

function Monster:stun(duration)
    self.stunned    = true
    self.stun_timer = Timer.new(duration)
end

local function centre(self)
    return self.x, self.y
end

local function pick_random_walkable(self)
    local w = self._walkable
    if #w == 0 then return nil end
    return w[love.math.random(1, #w)]
end

local function request_path_to_cell(self, gc, gr)
    local mc, mr = self.map:world_to_cell(self.x, self.y)
    local path   = self._pathfinder:find(mc, mr, gc, gr)
    self.path    = path
end

local function request_path_to_world(self, wx, wy)
    local gc, gr = self.map:world_to_cell(wx, wy)
    request_path_to_cell(self, gc, gr)
end

local function move_along_path(self, dt, speed)
    if not self.path or #self.path == 0 then return true end
    local node    = self.path[1]
    local wx, wy  = self.map:cell_to_world(node.col, node.row)
    local tx      = wx + CELL / 2
    local ty      = wy + CELL / 2
    local dx      = tx - self.x
    local dy      = ty - self.y
    local d       = math.sqrt(dx * dx + dy * dy)
    if d < 4 then
        table.remove(self.path, 1)
        if #self.path == 0 then return true end
    else
        local nx = dx / d
        local ny = dy / d
        self.x   = self.x + nx * speed * dt
        self.y   = self.y + ny * speed * dt
    end
    return false
end

local function move_toward(self, dt, tx, ty, speed)
    local dx = tx - self.x
    local dy = ty - self.y
    local d  = math.sqrt(dx * dx + dy * dy)
    if d < 1 then return true end
    self.x = self.x + (dx / d) * speed * dt
    self.y = self.y + (dy / d) * speed * dt
    return d < speed * dt
end

local function transition(self, state)
    self.state = state
end

function Monster:update(dt, player)
    if self.stunned then
        if self.stun_timer and self.stun_timer:update(dt) then
            self.stunned    = false
            self.stun_timer = nil
        end
        return
    end

    local mx, my   = self.x, self.y
    local pc       = player:centre()
    local px, py   = pc.x, pc.y
    local d_px     = dist(mx, my, px, py)

    if d_px < 48 and self.on_kill then self.on_kill() return end

    if self.step_timer:update(dt) then
        local cells = d_px / CELL
        if cells <= 3 then
            self.shake:trigger(6)
        elseif cells <= 6 then
            self.shake:trigger(3)
        elseif cells <= 10 then
            self.shake:trigger(1)
        end
    end

    if self.has_sight then
        local flashlight_glow = false
        for i = 1, 5 do
            local item = player.inventory.slots[i]
            if item and item.id == "flashlight" and item.active and item.on then
                flashlight_glow = true
                break
            end
        end

        if self.state == "chase" then
            if los_clear(self.map, mx, my, px, py) then
                self.sight_lost_timer = 0
                self.last_known_pos   = { x = px, y = py }
            else
                self.sight_lost_timer = self.sight_lost_timer + dt
                if self.sight_lost_timer > 3 then
                    transition(self, "search")
                    self.search_timer = 4
                    request_path_to_world(self, self.last_known_pos.x, self.last_known_pos.y)
                end
            end
        else
            local sight_range = 12 * CELL
            if (d_px <= sight_range and los_clear(self.map, mx, my, px, py)) or flashlight_glow then
                self.last_known_pos   = { x = px, y = py }
                self.sight_lost_timer = 0
                transition(self, "chase")
            end
        end
    end

    if self.has_hearing then
        if self.state ~= "chase" then
            if player:is_moving() and d_px < 8 * CELL then
                self.last_known_pos = { x = px, y = py }
                transition(self, "alerted")
                request_path_to_world(self, px, py)
            end
        end
    end

    if self.has_smell then
        if self.smell_timer:update(dt) then
            if self.state ~= "chase" then
                self.last_known_pos = { x = px, y = py }
                transition(self, "alerted")
                request_path_to_world(self, px, py)
            end
        end
    end

    if self.state == "wander" then
        local wander_speed = WANDER_SPEED + (self.has_speed and SPEED_BOOST or 0)
        local exhausted    = move_along_path(self, dt, wander_speed)
        if exhausted or not self.path then
            local cell = pick_random_walkable(self)
            if cell then
                request_path_to_cell(self, cell.col, cell.row)
            end
        end

    elseif self.state == "alerted" then
        local alerted_speed = WANDER_SPEED * 1.4
        local lkp           = self.last_known_pos
        if lkp then
            local exhausted = move_along_path(self, dt, alerted_speed)
            if exhausted then
                transition(self, "search")
                self.search_timer = 4
                self.path         = nil
            end
        else
            transition(self, "search")
            self.search_timer = 4
        end

    elseif self.state == "chase" then
        local chase_speed = CHASE_SPEED + (self.has_speed and SPEED_BOOST or 0)
        move_toward(self, dt, px, py, chase_speed)

    elseif self.state == "search" then
        local search_speed = WANDER_SPEED + (self.has_speed and SPEED_BOOST or 0)
        self.search_timer  = self.search_timer - dt

        local exhausted = move_along_path(self, dt, search_speed)
        if exhausted then
            if self.last_known_pos then
                local lkp = self.last_known_pos
                local ox  = love.math.random(-3, 3) * CELL
                local oy  = love.math.random(-3, 3) * CELL
                request_path_to_world(self, lkp.x + ox, lkp.y + oy)
            end
        end

        if self.search_timer <= 0 then
            self.last_known_pos = nil
            self.path           = nil
            transition(self, "wander")
        end
    end
end

function Monster:draw()
    if not self.visible then return end
    love.graphics.setColor(0.9, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", self.x - 8, self.y - 8, 16, 16)
    love.graphics.setColor(1, 1, 1, 1)
end

return Monster
