local Scene  = require("core/lua/scene")
local traits = require("game/data/traits")

local PlanningScene = {}
PlanningScene.__index = PlanningScene
setmetatable(PlanningScene, { __index = Scene })

local MAP_IDS   = { "forest", "hospital" }
local MAP_NAMES = { forest = "Forest Facility", hospital = "Abandoned Hospital" }

local COL_STASH   = 40
local COL_LOADOUT = 450
local COL_MISSION = 900
local ROW_START   = 60
local ROW_GAP     = 28

local HEADER_COLOR  = { 1, 0.85, 0.2, 1 }
local TEXT_COLOR    = { 1, 1, 1, 1 }
local DIM_COLOR     = { 0.5, 0.5, 0.5, 1 }
local CONFIRM_COLOR = { 0.3, 1, 0.4, 1 }
local TITLE_COLOR   = { 0.7, 0.1, 0.1, 1 }

local FONT_TITLE = love.graphics.newFont(32)

local W = 1280

local function roll_traits(budget)
    local pool = {}
    for i, t in ipairs(traits.all) do
        pool[i] = t
    end
    for i = #pool, 2, -1 do
        local j = love.math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local chosen = {}
    local spent  = 0
    for _, t in ipairs(pool) do
        if spent + t.cost <= budget then
            table.insert(chosen, t.id)
            spent = spent + t.cost
        end
    end
    return chosen
end

function PlanningScene.new(save_state)
    local self = setmetatable(Scene.new(), PlanningScene)
    self.save_state    = save_state or { stash = {} }
    self.map_idx       = 1
    self.budget        = 0
    self.loadout_idx   = 0
    return self
end

function PlanningScene:on_enter()
    self.loadout_idx = 0
end

function PlanningScene:_loadout_item()
    if self.loadout_idx == 0 then return nil end
    return self.save_state.stash[self.loadout_idx]
end

function PlanningScene:keypressed(key)
    if key == "m" then
        self.map_idx = (self.map_idx % #MAP_IDS) + 1

    elseif key == "l" then
        local max = #self.save_state.stash
        self.loadout_idx = (self.loadout_idx) % (max + 1) + 1
        if self.loadout_idx > max then self.loadout_idx = 0 end

    elseif key == "up" then
        self.budget = math.min(7, self.budget + 1)

    elseif key == "down" then
        self.budget = math.max(0, self.budget - 1)

    elseif key == "return" then
        local TraitRevealScene = require("game/scenes/trait_reveal_scene")
        local run_config = {
            map_id         = MAP_IDS[self.map_idx],
            budget         = self.budget,
            loadout_item   = self:_loadout_item(),
            monster_traits = roll_traits(self.budget),
        }
        local manager = require("game/scene_ref").manager
        manager:switch(TraitRevealScene.new(run_config, self.save_state))
    end
end

function PlanningScene:update(dt) end

function PlanningScene:draw()
    love.graphics.setColor(0.05, 0.05, 0.08, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, 720)

    local prev_font = love.graphics.getFont()
    love.graphics.setFont(FONT_TITLE)
    love.graphics.setColor(TITLE_COLOR)
    local title = "N I G H T F A L L"
    local tw = FONT_TITLE:getWidth(title)
    love.graphics.print(title, (W - tw) / 2, 12)
    love.graphics.setFont(prev_font)

    local stash = self.save_state.stash

    love.graphics.setColor(HEADER_COLOR)
    love.graphics.print("STASH", COL_STASH, ROW_START)
    love.graphics.setColor(DIM_COLOR)
    love.graphics.print("(items carry over between runs)", COL_STASH, ROW_START + 18)

    if #stash == 0 then
        love.graphics.setColor(DIM_COLOR)
        love.graphics.print("(empty)", COL_STASH, ROW_START + ROW_GAP * 2)
    else
        for i = 1, math.min(10, #stash) do
            love.graphics.setColor(TEXT_COLOR)
            love.graphics.print(i .. ".  " .. (stash[i].name or stash[i].id), COL_STASH, ROW_START + ROW_GAP * (i + 1))
        end
    end

    love.graphics.setColor(HEADER_COLOR)
    love.graphics.print("LOADOUT", COL_LOADOUT, ROW_START)
    love.graphics.setColor(DIM_COLOR)
    love.graphics.print("[L] cycle", COL_LOADOUT, ROW_START + 18)

    local loadout_item = self:_loadout_item()
    love.graphics.setColor(TEXT_COLOR)
    local loadout_name = loadout_item and (loadout_item.name or loadout_item.id) or "(none)"
    love.graphics.print("Slot 1:  " .. loadout_name, COL_LOADOUT, ROW_START + ROW_GAP * 2)

    love.graphics.setColor(HEADER_COLOR)
    love.graphics.print("MISSION", COL_MISSION, ROW_START)

    love.graphics.setColor(DIM_COLOR)
    love.graphics.print("[M] toggle map", COL_MISSION, ROW_START + 18)
    love.graphics.setColor(TEXT_COLOR)
    love.graphics.print("Map:  " .. MAP_NAMES[MAP_IDS[self.map_idx]], COL_MISSION, ROW_START + ROW_GAP * 2)

    love.graphics.setColor(DIM_COLOR)
    love.graphics.print("[UP/DOWN] budget", COL_MISSION, ROW_START + ROW_GAP * 3 + 4)
    love.graphics.setColor(TEXT_COLOR)
    love.graphics.print("Budget:  " .. self.budget .. " / 7", COL_MISSION, ROW_START + ROW_GAP * 4)

    local dots = ""
    for i = 1, 7 do
        dots = dots .. (i <= self.budget and "●" or "○") .. " "
    end
    love.graphics.setColor(HEADER_COLOR)
    love.graphics.print(dots, COL_MISSION, ROW_START + ROW_GAP * 5)

    love.graphics.setColor(CONFIRM_COLOR)
    love.graphics.print("[ENTER] CONFIRM", COL_MISSION, ROW_START + ROW_GAP * 7)

    love.graphics.setColor(1, 1, 1, 1)
end

return PlanningScene
