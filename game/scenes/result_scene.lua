local Scene = require("core/lua/scene")

local ResultScene = {}
ResultScene.__index = ResultScene
setmetatable(ResultScene, { __index = Scene })

local W, H = 1280, 720

local FONT_TITLE  = love.graphics.newFont(52)
local FONT_BODY   = love.graphics.newFont(22)
local FONT_PROMPT = love.graphics.newFont(18)

function ResultScene.new(params)
    local self = setmetatable(Scene.new(), ResultScene)
    self.outcome    = params.outcome
    self.save_state = params.save_state
    self._loot      = params.loot or {}
    return self
end

function ResultScene:on_enter()
    self._elapsed = 0
end

function ResultScene:keypressed(key)
    if self._elapsed < 1.5 then return end
    local PlanningScene = require("game/scenes/planning_scene")
    local manager       = require("game/scene_ref").manager
    manager:switch(PlanningScene.new(self.save_state))
end

function ResultScene:update(dt)
    self._elapsed = (self._elapsed or 0) + dt
end

function ResultScene:draw()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(FONT_TITLE)

    local title, tr, tg, tb
    if self.outcome == "extracted" then
        title = "EXTRACTION SUCCESSFUL"
        tr, tg, tb = 0.2, 1, 0.3
    else
        title = "YOU DIED"
        tr, tg, tb = 1, 0.15, 0.15
    end

    love.graphics.setColor(tr, tg, tb, 1)
    local tw = FONT_TITLE:getWidth(title)
    love.graphics.print(title, (W - tw) / 2, H / 2 - 180)

    love.graphics.setFont(FONT_BODY)

    if self.outcome == "extracted" then
        love.graphics.setColor(1, 1, 1, 1)
        local label = "Items added to stash:"
        local lw = FONT_BODY:getWidth(label)
        love.graphics.print(label, (W - lw) / 2, H / 2 - 80)

        if #self._loot == 0 then
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            local el = "(none)"
            local ew = FONT_BODY:getWidth(el)
            love.graphics.print(el, (W - ew) / 2, H / 2 - 44)
        else
            for i, item in ipairs(self._loot) do
                love.graphics.setColor(1, 1, 1, 1)
                local il = (item.name or item.id)
                local iw = FONT_BODY:getWidth(il)
                love.graphics.print(il, (W - iw) / 2, H / 2 - 44 + (i - 1) * 30)
            end
        end
    end

    local t     = love.timer.getTime()
    local alpha = 0.4 + 0.6 * math.abs(math.sin(t * math.pi))
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(FONT_PROMPT)
    local prompt = "PRESS ANY KEY TO CONTINUE"
    local pw = FONT_PROMPT:getWidth(prompt)
    love.graphics.print(prompt, (W - pw) / 2, H - 80)

    love.graphics.setColor(1, 1, 1, 1)
end

return ResultScene
