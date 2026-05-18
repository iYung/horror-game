local Scene       = require("core/lua/scene")
local Player      = require("game/entities/player")
local Monster     = require("game/entities/monster")
local FOV         = require("game/systems/fov")
local CameraShake = require("game/systems/camera_shake")
local Extraction  = require("game/systems/extraction")
local ItemSpawner = require("game/world/item_spawner")
local HUD         = require("game/ui/hud")

local RunScene = {}
RunScene.__index = RunScene
setmetatable(RunScene, { __index = Scene })

local function load_map(map_id)
    if map_id == "hospital" then
        return require("game/world/map_hospital")
    end
    return require("game/world/map_forest")
end

local function draw_ground_items(ground_items)
    love.graphics.setColor(1, 0.9, 0.3, 1)
    for _, entry in ipairs(ground_items) do
        love.graphics.rectangle("fill", entry.x - 5, entry.y - 5, 10, 10)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function wrap_flare_gun(item, extraction)
    if item._extraction_wrapped then return end
    item._extraction_wrapped = true
    local original_use = item.use_fn
    item.use_fn = function(p, world)
        if extraction:in_zone(p) then
            local result = original_use(p, world)
            if result == "extract" then
                extraction:try_start(p)
            end
        end
    end
end

function RunScene.new(run_config, save_state)
    local self = setmetatable(Scene.new(), RunScene)
    self.run_config  = run_config
    self.save_state  = save_state
    self._dead       = false
    self._extracted  = false
    return self
end

function RunScene:on_enter()
    self._dead      = false
    self._extracted = false
    self._shake_ox  = 0
    self._shake_oy  = 0

    local map = load_map(self.run_config.map_id)
    self.map  = map

    self.shake = CameraShake.new()

    local ex = map.extraction.x
    local ey = map.extraction.y
    self.monster = Monster.new(ex, ey, map, self.shake, self.run_config.monster_traits)

    self.player = Player.new(map.spawn.x, map.spawn.y, map)
    if self.run_config.loadout_item then
        self.player.inventory:set_slot(1, self.run_config.loadout_item)
    end

    self.ground_items = ItemSpawner.spawn(map, self.run_config.budget)

    self.fov        = FOV.new(map)
    self.extraction = Extraction.new(map)
    self.hud        = HUD.new(self.player.inventory, self.extraction)

    self.monster.on_kill = function()
        if not self._dead then
            self._dead = true
            local manager     = require("game/scene_ref").manager
            local ResultScene = require("game/scenes/result_scene")
            manager:switch(ResultScene.new({ outcome = "death", save_state = self.save_state }))
        end
    end

    local extraction_ref = self.extraction
    for _, entry in ipairs(self.ground_items) do
        if entry.item and entry.item.id == "flare_gun" then
            wrap_flare_gun(entry.item, extraction_ref)
        end
    end
    for i = 1, 5 do
        local item = self.player.inventory.slots[i]
        if item and item.id == "flare_gun" then
            wrap_flare_gun(item, extraction_ref)
        end
    end

    self.player.on_use = function(p) end

    self.player.on_pickup = function(entry)
        for i = #self.ground_items, 1, -1 do
            if self.ground_items[i] == entry then
                table.remove(self.ground_items, i)
                break
            end
        end
        if entry.item and entry.item.id == "flare_gun" then
            wrap_flare_gun(entry.item, extraction_ref)
        end
    end

    self.drawer:add(map, 1)
    self.drawer:add(self.player, 10)
    self.drawer:add(self.monster, 10)

    self._ground_drawable = { draw = function()
        draw_ground_items(self.ground_items)
    end }
    self.drawer:add(self._ground_drawable, 5)
end

function RunScene:update(dt)
    if self._dead or self._extracted then return end

    self.player:update(dt, self.ground_items)

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

    local extraction_result = self.extraction:update(dt, self.player)
    if extraction_result == "extracted" and not self._extracted then
        self._extracted = true
        local stash = self.save_state.stash
        local loot  = {}
        for i = 1, 5 do
            local item = self.player.inventory.slots[i]
            if item and #stash < 10 then
                table.insert(stash, item)
                table.insert(loot, item)
            end
        end
        local manager     = require("game/scene_ref").manager
        local ResultScene = require("game/scenes/result_scene")
        manager:switch(ResultScene.new({ outcome = "extracted", save_state = self.save_state, loot = loot }))
        return
    end

    local pc = self.player:centre()
    self.camera:follow(pc, 0.85)
    self.shake:update(dt)
    local ox, oy = self.shake:offset()
    self._shake_ox = ox
    self._shake_oy = oy

    self.fov:update(pc.x, pc.y,
        self.player.facing.dx, self.player.facing.dy,
        self.player.inventory:active())

    self.monster.visible = self.fov:is_visible(self.monster.x + 8, self.monster.y + 8)
end

local function draw_extraction_zone(extraction, map)
    local ex = map.extraction.x
    local ey = map.extraction.y
    local r  = map.extraction.radius
    local t  = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 3)

    if extraction:is_active() then
        love.graphics.setColor(0.2, 1.0, 0.3, 0.3 + 0.4 * pulse)
    else
        love.graphics.setColor(0.2, 0.8, 0.2, 0.15 + 0.15 * pulse)
    end
    love.graphics.circle("fill", ex, ey, r)

    love.graphics.setColor(0.3, 1.0, 0.3, 0.6 + 0.3 * pulse)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", ex, ey, r)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function RunScene:draw()
    self.camera:attach()
    love.graphics.translate(self._shake_ox or 0, self._shake_oy or 0)
    self.drawer:draw()
    draw_extraction_zone(self.extraction, self.map)
    self.fov:draw(self.player.inventory:active())
    self.camera:detach()

    self.hud:draw()
end

function RunScene:keypressed(key)
    if key == "escape" then
        local manager       = require("game/scene_ref").manager
        local PlanningScene = require("game/scenes/planning_scene")
        manager:switch(PlanningScene.new(self.save_state))
    end
end

return RunScene
