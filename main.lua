local headless = false
for _, v in ipairs(arg or {}) do
    if v == "--headless" then
        headless = true
        break
    end
end

if headless then
    function love.load()
        require("busted.runner")({ "--output=utfTerminal", "test/" })
        love.event.quit(0)
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
