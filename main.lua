local headless = false
local watch    = false
for _, v in ipairs(arg or {}) do
    if v == "--headless" then headless = true end
    if v == "--watch"    then watch    = true end
end

-- Collect every test_*.lua in tests/ so both headless and watch always run the
-- same suite. Adding a new test file requires no changes here.
local function find_tests()
    local files = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems("tests")) do
        if name:match("^test_.*%.lua$") then
            table.insert(files, "tests/" .. name:gsub("%.lua$", ""))
        end
    end
    table.sort(files)
    return files
end

if headless then
    function love.load()
        require("tests/runner").run(find_tests())
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
        local runner     = require("tests/runner")
        local WatchScene = require("tests/watch_scene")
        manager:switch(WatchScene.new(runner.collect(find_tests())))
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
