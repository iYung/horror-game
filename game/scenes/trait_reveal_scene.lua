local Scene  = require("core/lua/scene")
local traits = require("game/data/traits")

local TraitRevealScene = {}
TraitRevealScene.__index = TraitRevealScene
setmetatable(TraitRevealScene, { __index = Scene })

local TITLE_COLOR = { 0.9, 0.2, 0.2, 1 }
local TEXT_COLOR  = { 1, 1, 1, 1 }
local DIM_COLOR   = { 0.6, 0.6, 0.6, 1 }

local W, H = 1280, 720

local FONT_TITLE  = love.graphics.newFont(48)
local FONT_BODY   = love.graphics.newFont(22)
local FONT_PROMPT = love.graphics.newFont(18)

local function trait_name(id)
    local t = traits[id]
    return t and t.name or id
end

function TraitRevealScene.new(run_config, save_state)
    local self = setmetatable(Scene.new(), TraitRevealScene)
    self.run_config  = run_config
    self.save_state  = save_state
    return self
end

function TraitRevealScene:on_enter() end

function TraitRevealScene:keypressed(key)
    local RunScene = require("game/scenes/run_scene")
    local manager  = require("game/scene_ref").manager
    manager:switch(RunScene.new(self.run_config, self.save_state))
end

function TraitRevealScene:update(dt) end

function TraitRevealScene:draw()
    local grain = love.math.random() * 0.03
    love.graphics.setColor(grain, grain, grain, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(TITLE_COLOR)
    love.graphics.setFont(FONT_TITLE)
    local title = "THE HOLLOW"
    local tw = FONT_TITLE:getWidth(title)
    love.graphics.print(title, (W - tw) / 2, H / 2 - 160)

    love.graphics.setFont(FONT_BODY)

    local mt = self.run_config.monster_traits
    if #mt == 0 then
        love.graphics.setColor(DIM_COLOR)
        local label = "NO TRAITS DETECTED"
        local lw = FONT_BODY:getWidth(label)
        love.graphics.print(label, (W - lw) / 2, H / 2 - 60)
    else
        for i, id in ipairs(mt) do
            love.graphics.setColor(TEXT_COLOR)
            local label = trait_name(id)
            local lw = FONT_BODY:getWidth(label)
            love.graphics.print(label, (W - lw) / 2, H / 2 - 60 + (i - 1) * 34)
        end
    end

    local t     = love.timer.getTime()
    local alpha = 0.4 + 0.6 * math.abs(math.sin(t * math.pi))
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(FONT_PROMPT)
    local prompt = "PRESS ANY KEY TO BEGIN"
    local pw = FONT_PROMPT:getWidth(prompt)
    love.graphics.print(prompt, (W - pw) / 2, H - 80)

    love.graphics.setColor(1, 1, 1, 1)
end

return TraitRevealScene
