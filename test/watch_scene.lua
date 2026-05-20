local Scene3D    = require("core/lua/scene_3d")
local Map        = require("game/world/map")
local Simulation = require("game/simulation")

local CELL = Map.CELL

local WatchScene = setmetatable({}, { __index = Scene3D })
WatchScene.__index = WatchScene

local function fog_range(player)
    local item = player:active_item()
    if item then
        if item.id == "flashlight" and item.active and item.on then return 14 end
    end
    return 8
end

local function build_sprites(sim)
    local sprites = {}
    local t       = love.timer.getTime()

    table.insert(sprites, {
        x     = sim.monster.x / CELL + 1,
        y     = sim.monster.y / CELL + 1,
        size  = 0.8,
        color = {0.9, 0.1, 0.1, 1},
    })

    for _, entry in ipairs(sim.ground_items) do
        local is_flare = entry.item and entry.item.id == "flare_gun"
        table.insert(sprites, {
            x     = entry.x / CELL + 1,
            y     = entry.y / CELL + 1,
            size  = 0.4,
            color = is_flare and {1, 0.2, 0.8, 1} or {1, 0.9, 0.3, 1},
        })
    end

    local ez    = sim.map.extraction
    local pulse = 0.5 + 0.5 * math.sin(t * 3)
    local alpha = sim.extraction:is_active()
        and (0.7 + 0.3 * pulse)
        or  (0.3 + 0.2 * pulse)
    table.insert(sprites, {
        x     = ez.x / CELL + 1,
        y     = ez.y / CELL + 1,
        size  = 2.0,
        color = {0.1, 1.0, 0.2, alpha},
    })

    return sprites
end

function WatchScene.new(tests)
    local self = setmetatable(Scene3D.new(), WatchScene)
    self._tests          = tests
    self._index          = 0
    self._results        = {}
    self._co             = nil
    self._label          = ""
    self._state          = "running"
    self._steps_per_frame = 1
    return self
end

function WatchScene:on_enter()
    self:_advance()
end

function WatchScene:_advance()
    self._index = self._index + 1
    if self._index > #self._tests then
        self._state = "summary"
        self._co    = nil
        return
    end
    local t      = self._tests[self._index]
    self._label  = t.name
    self._co     = coroutine.create(t.fn)
end

function WatchScene:update(dt)
    if self._state ~= "running" or not self._co then return end

    for _ = 1, self._steps_per_frame do
        if not self._co then break end
        local ok, err = coroutine.resume(self._co)
        if not ok then
            table.insert(self._results, { name = self._label, pass = false, err = tostring(err) })
            self:_advance()
            break
        elseif coroutine.status(self._co) == "dead" then
            table.insert(self._results, { name = self._label, pass = true })
            self:_advance()
            break
        end
    end
end

function WatchScene:draw()
    local sim = Simulation._current

    if sim then
        self.raycaster:draw(
            sim.map,
            sim.player.x, sim.player.y,
            sim.player.angle + sim.shake:angle_offset(),
            {
                fog_range = fog_range(sim.player),
                sprites   = build_sprites(sim),
            }
        )
    end

    local W = love.graphics.getWidth()

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, 28)
    love.graphics.setColor(1, 1, 1, 1)

    if self._state == "running" then
        local header = string.format("[%d/%d] %s  (speed %dx — -/= to change)",
            self._index, #self._tests, self._label, self._steps_per_frame)
        love.graphics.print(header, 8, 6)

        if sim then
            local info = string.format("t=%.2fs  monster=%s", sim._tick, sim.monster.state)
            love.graphics.print(info, W - 220, 6)
        end

    elseif self._state == "summary" then
        local pass = 0
        for _, r in ipairs(self._results) do if r.pass then pass = pass + 1 end end
        love.graphics.print(
            string.format("DONE: %d/%d passed — press any key to quit", pass, #self._tests),
            8, 6
        )

        local y = 50
        for _, r in ipairs(self._results) do
            if r.pass then
                love.graphics.setColor(0.3, 1, 0.3, 1)
                love.graphics.print("PASS  " .. r.name, 20, y)
            else
                love.graphics.setColor(1, 0.3, 0.3, 1)
                love.graphics.print("FAIL  " .. r.name, 20, y)
                if r.err then
                    love.graphics.setColor(0.8, 0.5, 0.5, 1)
                    love.graphics.print("      " .. r.err, 20, y + 18)
                    y = y + 18
                end
            end
            y = y + 24
        end

        love.graphics.setColor(1, 1, 1, 1)
    end
end

function WatchScene:keypressed(key)
    if self._state == "summary" then
        love.event.quit(0)
    elseif key == "=" or key == "+" then
        self._steps_per_frame = math.min(self._steps_per_frame * 10, 1000)
    elseif key == "-" then
        self._steps_per_frame = math.max(math.floor(self._steps_per_frame / 10), 1)
    end
end

return WatchScene
