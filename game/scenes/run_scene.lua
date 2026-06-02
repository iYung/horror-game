local Scene3D     = require("core/lua/scene_3d")
local Drawer      = require("core/lua/drawer")
local Player      = require("game/entities/player")
local Monster     = require("game/entities/monster")
local CameraShake = require("game/systems/camera_shake")
local Extraction  = require("game/systems/extraction")
local ItemSpawner = require("game/world/item_spawner")
local HUD         = require("game/ui/hud")
local Map         = require("game/world/map")

local CELL = Map.CELL

local RunScene = setmetatable({}, { __index = Scene3D })
RunScene.__index = RunScene

local function load_map(map_id)
    if map_id == "hospital" then
        return require("game/world/map_hospital")
    end
    return require("game/world/map_forest")
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
                p.inventory:remove_item_by_ref(item)
            end
        end
    end
end

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
        end
    end
end

function RunScene.new(run_config, save_state)
    local self = setmetatable(Scene3D.new(), RunScene)
    self.run_config  = run_config
    self.save_state  = save_state
    self._dead       = false
    self._extracted  = false
    self.esc_opens_settings = true
    return self
end

function RunScene:on_enter()
    self._dead        = false
    self._extracted   = false
    self._shake_angle = 0

    local map = load_map(self.run_config.map_id)
    self.map  = map

    self.shake = CameraShake.new()

    -- Monster spawns at extraction zone (pixel coords — monster stays in pixel space)
    self.monster = Monster.new(
        map.extraction.x, map.extraction.y,
        map, self.shake, self.run_config.monster_traits)

    -- Player spawns at center of spawn cell, in 1-indexed grid units
    -- spawn.x is a pixel top-left; /CELL gives 0-indexed, +1.5 centers in the 1-indexed cell
    local spawn_gx = map.spawn.x / CELL + 1.5
    local spawn_gy = map.spawn.y / CELL + 1.5
    self.player = Player.new(spawn_gx, spawn_gy, map)
    if self.run_config.loadout_item then
        self.player.inventory:set_slot(1, self.run_config.loadout_item)
    end

    self.ground_items = ItemSpawner.spawn(map, self.run_config.budget)
    self.extraction   = Extraction.new(map)
    self.hud          = HUD.new(self.player.inventory, self.extraction, self.player, self.monster)

    -- Drawer holds 2D HUD overlay only; 3D world is rendered via self.raycaster
    self.drawer = Drawer.new()
    self.drawer:add(self.hud, 1)

    self.monster.on_kill = function()
        if not self._dead then
            self._dead = true
            local manager     = require("game/scene_ref").manager
            local ResultScene = require("game/scenes/result_scene")
            manager:switch(ResultScene.new({ outcome = "death", save_state = self.save_state }))
        end
    end

    local extraction_ref = self.extraction
    local function maybe_wrap(item)
        if item and item.id == "flare_gun" then
            wrap_flare_gun(item, extraction_ref)
        end
    end
    for _, entry in ipairs(self.ground_items) do maybe_wrap(entry.item) end
    for i = 1, 5 do maybe_wrap(self.player.inventory.slots[i]) end

    local function maybe_wrap_taser(item)
        if item and item.id == "taser" then
            wrap_taser(item, self.monster, self.player)
        end
    end
    for _, entry in ipairs(self.ground_items) do maybe_wrap_taser(entry.item) end
    for i = 1, 5 do maybe_wrap_taser(self.player.inventory.slots[i]) end

    self.player.on_use = function(p) end

    self.player.on_pickup = function(entry)
        for i = #self.ground_items, 1, -1 do
            if self.ground_items[i] == entry then
                table.remove(self.ground_items, i)
                break
            end
        end
        maybe_wrap(entry.item)
        maybe_wrap_taser(entry.item)
    end
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

    for i = 1, 5 do
        local item = self.player.inventory.slots[i]
        if item and item.update then
            item.update(dt, self.player.inventory)
        end
    end

    self.monster:update(dt, self.player)

    local result = self.extraction:update(dt, self.player)
    if result == "extracted" and not self._extracted then
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

    self.shake:update(dt)
    self._shake_angle = self.shake:angle_offset()
end

-- Build point-light list for the current frame
local function build_lights(self)
    local lights = {}
    for _, t in ipairs(self.map.torches) do
        table.insert(lights, { x = t.col + 0.5, y = t.row + 0.5, radius = 6, intensity = 1.0 })
    end
    for i = 1, 5 do
        local item = self.player.inventory.slots[i]
        if item and item.id == "flashlight" and item.active and item.on then
            table.insert(lights, { x = self.player.x, y = self.player.y, radius = 6, intensity = 1.0 })
            break
        end
    end
    return lights
end

-- Build billboard sprite list for the current frame
local function build_sprites(self)
    local sprites = {}
    local t       = love.timer.getTime()

    -- Monster
    table.insert(sprites, {
        x     = self.monster.x / CELL + 1,
        y     = self.monster.y / CELL + 1,
        size  = 0.8,
        color = {0.9, 0.1, 0.1, 1},
    })

    -- Ground items
    for _, entry in ipairs(self.ground_items) do
        local id = entry.item and entry.item.id
        local color = id == "flare_gun"   and {1, 0.2, 0.8, 1}
                   or id == "compass"    and {0.3, 0.8, 1.0, 1}
                   or id == "tracker"   and {1, 0.4, 0.1, 1}
                   or id == "adrenaline" and {0.2, 1.0, 0.4, 1}
                   or id == "taser"      and {0.3, 0.8, 1.0, 1}
                   or                       {1, 0.9, 0.3, 1}
        table.insert(sprites, {
            x     = entry.x / CELL + 1,
            y     = entry.y / CELL + 1,
            size  = 0.4,
            color = color,
        })
    end

    -- Extraction zone — tall green pillar, pulses when active
    local ez    = self.map.extraction
    local pulse = 0.5 + 0.5 * math.sin(t * 3)
    local alpha = self.extraction:is_active()
        and (0.7 + 0.3 * pulse)
        or  (0.3 + 0.2 * pulse)
    table.insert(sprites, {
        x     = ez.x / CELL + 1,
        y     = ez.y / CELL + 1,
        size  = 2.0,
        color = {0.1, 1.0, 0.2, alpha},
    })

    for _, t in ipairs(self.map.torches) do
        table.insert(sprites, {
            x     = t.col + 0.5,
            y     = t.row + 0.5,
            size  = 0.25,
            color = {1.0, 0.65, 0.15, 1},
        })
    end

    return sprites
end

function RunScene:draw()
    self.raycaster:draw(
        self.map,
        self.player.x, self.player.y,
        self.player.angle + self._shake_angle,
        {
            lights    = build_lights(self),
            sprites   = build_sprites(self),
        }
    )
    -- 2D overlay: HUD drawn in screen space after the 3D pass
    self.drawer:draw()
end

return RunScene
