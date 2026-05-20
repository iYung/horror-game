local headless = false
local watch    = false
for _, v in ipairs(arg or {}) do
    if v == "--headless" then headless = true end
    if v == "--watch"    then watch    = true end
end

if headless then
    function love.load()
        require("test/runner").run({ "test/run_test", "test/torches_test" })
    end
elseif watch then
    local SceneManager = require("core/lua/scene_manager")
    local scene_ref    = require("game/scene_ref")
    local Simulation   = require("game/simulation")

    local manager = SceneManager.new()
    scene_ref.manager = manager

    function love.load()
        love.window.setMode(1280, 720)
        love.window.setTitle("NIGHTFALL — WATCH")
        Simulation._watching = true
        local runner     = require("test/runner")
        local WatchScene = require("test/watch_scene")
        manager:switch(WatchScene.new(runner.collect({ "test/run_test" })))
    end

    function love.update(dt) manager:update(dt) end
    function love.draw()    manager:draw()    end

    function love.keypressed(key)
        if manager.current and manager.current.keypressed then
            manager.current:keypressed(key)
        end
    end
else
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
        if manager.current and manager.current.keypressed then
            manager.current:keypressed(key)
        end
    end
end
