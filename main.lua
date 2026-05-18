local SceneManager  = require("core/lua/scene_manager")
local PlanningScene = require("game/scenes/planning_scene")
local scene_ref     = require("game/scene_ref")

local manager = SceneManager.new()
scene_ref.manager = manager

function love.load()
    love.window.setMode(1280, 720)
    love.window.setTitle("NIGHTFALL")
    manager:switch(PlanningScene.new())
end

function love.update(dt)
    manager:update(dt)
end

function love.draw()
    manager:draw()
end

function love.keypressed(key)
    manager:keypressed(key)
end
