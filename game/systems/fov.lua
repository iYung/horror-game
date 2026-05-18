-- FOV (Field of View)
-- Raycasts from the player each frame to determine which map cells are visible.
-- Maintains two sets: `visible` (this frame only) and `explored` (ever seen).
-- draw() renders the fog overlay on top of the world: black for unexplored,
-- semi-transparent black for explored-but-dark, nothing for currently lit.
--
-- Two passes per frame:
--   1. Directional cone  — facing direction ± ANGLE, up to RANGE cells, wall-blocked.
--   2. Ambient ring      — full 360°, AMBIENT_R cells, always on.
-- Item modifiers: flashlight widens/extends the cone; torch adds a 5-cell omni pass.
--
-- Usage:
--   fov = FOV.new(map)
--   fov:update(px, py, facing_dx, facing_dy, active_item)  -- call every frame
--   fov:draw(active_item)                                   -- call after drawer:draw(), inside camera
--   fov:is_visible(wx, wy)   -- world-space point visible this frame?
--   fov:is_explored(col,row) -- cell ever seen?

local Map = require("game/world/map")

local FOV = {}
FOV.__index = FOV

FOV.RANGE      = 14
FOV.ANGLE      = math.rad(55)
FOV.AMBIENT_R  = 3
FOV.TORCH_R    = 5
FOV.FL_RANGE   = 18
FOV.FL_ANGLE   = math.rad(80)

local STEP        = 0.5
local CELL        = Map.CELL
local RAY_COUNT   = 180
local AMBIENT_RAYS = 36

function FOV.new(map)
    local self      = setmetatable({}, FOV)
    self.map        = map
    self.visible    = {}
    self.explored   = {}
    self.px         = 0
    self.py         = 0
    self.facing_dx  = 1
    self.facing_dy  = 0
    return self
end

local function key(col, row)
    return col * 1000 + row
end

function FOV:update(px, py, facing_dx, facing_dy, active_item)
    self.visible   = {}
    self.px        = px
    self.py        = py

    local len = math.sqrt(facing_dx * facing_dx + facing_dy * facing_dy)
    if len == 0 then
        facing_dx, facing_dy = 1, 0
    else
        facing_dx = facing_dx / len
        facing_dy = facing_dy / len
    end
    self.facing_dx = facing_dx
    self.facing_dy = facing_dy

    local torch_active = active_item and active_item.id == "torch" and active_item.active
    local fl_active    = active_item and active_item.id == "flashlight" and active_item.active and active_item.on

    local base_angle = math.atan2(facing_dy, facing_dx)
    local range_px   = (fl_active and FOV.FL_RANGE or FOV.RANGE) * CELL
    local half       = fl_active and FOV.FL_ANGLE or FOV.ANGLE

    for i = 0, RAY_COUNT - 1 do
        local angle = base_angle - half + (2 * half) * (i / (RAY_COUNT - 1))
        local rdx   = math.cos(angle)
        local rdy   = math.sin(angle)
        local steps = range_px / STEP

        for s = 0, steps do
            local wx = px + rdx * s * STEP
            local wy = py + rdy * s * STEP
            local col, row = self.map:world_to_cell(wx, wy)

            local k = key(col, row)
            self.visible[k]   = true
            self.explored[k]  = true

            if self.map:is_wall(col, row) then
                break
            end
        end
    end

    -- ambient 360° ring always active
    local ambient_px = FOV.AMBIENT_R * CELL
    for i = 0, AMBIENT_RAYS - 1 do
        local angle = (2 * math.pi) * (i / AMBIENT_RAYS)
        local rdx   = math.cos(angle)
        local rdy   = math.sin(angle)
        for s = 0, ambient_px / STEP do
            local wx = px + rdx * s * STEP
            local wy = py + rdy * s * STEP
            local col, row = self.map:world_to_cell(wx, wy)
            local k = key(col, row)
            self.visible[k]  = true
            self.explored[k] = true
            if self.map:is_wall(col, row) then break end
        end
    end

    if torch_active then
        local torch_px = FOV.TORCH_R * CELL
        local omni_steps = torch_px / STEP
        local omni_rays  = 36
        for i = 0, omni_rays - 1 do
            local angle = (2 * math.pi) * (i / omni_rays)
            local rdx   = math.cos(angle)
            local rdy   = math.sin(angle)
            for s = 0, omni_steps do
                local wx = px + rdx * s * STEP
                local wy = py + rdy * s * STEP
                local col, row = self.map:world_to_cell(wx, wy)
                local k = key(col, row)
                self.visible[k]  = true
                self.explored[k] = true
                if self.map:is_wall(col, row) then
                    break
                end
            end
        end
    end

    self._torch_active = torch_active
end

function FOV:is_visible(wx, wy)
    local col, row = self.map:world_to_cell(wx, wy)
    return self.visible[key(col, row)] == true
end

function FOV:is_explored(col, row)
    return self.explored[key(col, row)] == true
end

function FOV:draw(active_item)
    local C    = CELL
    local cols = Map.COLS
    local rows = Map.ROWS

    for row = 1, rows do
        for col = 1, cols do
            local k = key(col, row)
            local x = (col - 1) * C
            local y = (row - 1) * C

            if not self.explored[k] then
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("fill", x, y, C, C)
            elseif not self.visible[k] then
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("fill", x, y, C, C)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return FOV
