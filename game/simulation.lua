-- Simulation
-- Headless run harness that mirrors RunScene's setup and update logic without any
-- rendering, raycaster, HUD, Drawer, or scene management. Used for AI playtesting
-- and automated balance analysis.
--
-- Usage:
--   local Simulation = require("game/simulation")
--   local sim = Simulation.new(run_config)
--   local state = sim:step(1/60, { fwd = true })
--   local final = sim:run_until(function(s) return s.outcome ~= nil end)

local Player      = require("game/entities/player")
local Monster     = require("game/entities/monster")
local CameraShake = require("game/systems/camera_shake")
local Extraction  = require("game/systems/extraction")
local ItemSpawner = require("game/world/item_spawner")
local Map         = require("game/world/map")
local SimInput    = require("core/lua/sim_input")

local CELL = Map.CELL

local Simulation = {}
Simulation.__index = Simulation
Simulation._current  = nil
Simulation._watching = false

local function load_map(map_id)
    if map_id == "hospital" then
        return require("game/world/map_hospital")
    end
    return require("game/world/map_forest")
end

function Simulation.new(run_config)
    local self = setmetatable({}, Simulation)

    local map = load_map(run_config.map_id)
    self.map  = map

    self.shake = CameraShake.new()

    self._sim_input = SimInput.new()

    -- Monster spawns at extraction zone in pixel coords (same as RunScene)
    self.monster = Monster.new(
        map.extraction.x, map.extraction.y,
        map, self.shake, run_config.monster_traits)

    -- Player spawns at center of spawn cell in 1-indexed grid units (same as RunScene)
    local spawn_gx = map.spawn.x / CELL + 1.5
    local spawn_gy = map.spawn.y / CELL + 1.5
    self.player = Player.new(spawn_gx, spawn_gy, map, self._sim_input)

    if run_config.loadout_item then
        self.player.inventory:set_slot(1, run_config.loadout_item)
    end

    self.ground_items = ItemSpawner.spawn(map, run_config.budget)
    self.extraction   = Extraction.new(map)

    local extraction_ref = self.extraction

    local function wrap_flare_gun(item)
        if not item or item.id ~= "flare_gun" or item._extraction_wrapped then return end
        item._extraction_wrapped = true
        local original_use = item.use_fn
        item.use_fn = function(p, world)
            if extraction_ref:in_zone(p) then
                local result = original_use(p, world)
                if result == "extract" then
                    extraction_ref:try_start(p)
                    p.inventory:remove_item_by_ref(item)
                end
            end
        end
    end

    local function wrap_taser(item)
        if not item or item.id ~= "taser" or item._taser_wrapped then return end
        item._taser_wrapped = true
        local original_use = item.use_fn
        local monster_ref  = self.monster
        item.use_fn = function(p, world)
            local result = original_use(p, world)
            if result == "stun" then
                local pc   = p:centre()
                local dx   = monster_ref.x - pc.x
                local dy   = monster_ref.y - pc.y
                local d_px = math.sqrt(dx * dx + dy * dy)
                if d_px <= 96 then
                    monster_ref:stun(4)
                end
            end
        end
    end

    for _, entry in ipairs(self.ground_items) do wrap_flare_gun(entry.item) end
    for i = 1, 5 do wrap_flare_gun(self.player.inventory.slots[i]) end
    for _, entry in ipairs(self.ground_items) do wrap_taser(entry.item) end
    for i = 1, 5 do wrap_taser(self.player.inventory.slots[i]) end

    self.player.on_pickup = function(entry)
        for i = #self.ground_items, 1, -1 do
            if self.ground_items[i] == entry then
                table.remove(self.ground_items, i)
                break
            end
        end
        wrap_flare_gun(entry.item)
        wrap_taser(entry.item)
    end

    self._outcome  = nil
    self._tick     = 0
    self._yield_fn = Simulation._watching and coroutine.yield or nil

    self.monster.on_kill = function()
        self._outcome = "death"
    end

    Simulation._current = self
    return self
end

function Simulation:step(dt, actions)
    if self._outcome then return nil end

    -- Inject actions for this tick before player:update reads them
    self._sim_input:inject(actions or {})

    self.player:update(dt, self.ground_items)

    -- Burn down item timers and prune expired entries (mirrors RunScene:update)
    for i = #self.ground_items, 1, -1 do
        local entry = self.ground_items[i]
        if entry.item and entry.item.update then
            entry.item.update(dt, self.player.inventory)
        end
    end
    for i = #self.ground_items, 1, -1 do
        if self.ground_items[i].item == nil then
            table.remove(self.ground_items, i)
        end
    end

    self.monster:update(dt, self.player)

    local result = self.extraction:update(dt, self.player)
    if result == "extracted" or result == "failed" then
        self._outcome = result
    end

    self._tick = self._tick + dt

    self.shake:update(dt)

    if self._yield_fn then self._yield_fn() end

    return self:state()
end

function Simulation:state()
    return {
        outcome  = self._outcome,
        tick     = self._tick,
        player   = {
            x     = self.player.x,
            y     = self.player.y,
            angle = self.player.angle,
        },
        monster  = {
            x     = self.monster.x,
            y     = self.monster.y,
            state = self.monster.state,
        },
        extraction = {
            active         = self.extraction:is_active(),
            discovered     = self.extraction.discovered,
            time_remaining = self.extraction:time_remaining(),
        },
    }
end

function Simulation:run_until(pred, opts)
    opts = opts or {}
    local dt          = opts.dt          or (1 / 60)
    local max_seconds = opts.max_seconds or 120

    while true do
        local state = self:step(dt)
        -- step() returns nil once outcome is set; retrieve final state directly
        if not state then
            return self:state()
        end
        if self._tick >= max_seconds then
            return state
        end
        if pred(state) then
            return state
        end
    end
end

return Simulation
