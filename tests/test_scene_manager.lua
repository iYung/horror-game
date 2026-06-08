local SceneManager = require("core/lua/scene_manager")

local function mock_scene(name)
    local s = { name = name, entered = 0, exited = 0, updated = 0 }
    s.on_enter = function() s.entered = s.entered + 1 end
    s.on_exit  = function() s.exited  = s.exited  + 1 end
    s.update   = function() s.updated = s.updated + 1 end
    s.draw     = function() end
    return s
end

describe("SceneManager", function()

    it("first switch skips fade and calls on_enter immediately", function()
        local sm = SceneManager.new()
        local a  = mock_scene("a")

        sm:switch(a)

        assert.are.equal(1,      a.entered)
        assert.are.equal(0,      a.exited)
        assert.are.equal("idle", sm._fade_state)
        assert.are.equal(a,      sm.current)
    end)

    it("second switch starts fade-out, calls on_enter but defers on_exit", function()
        local sm = SceneManager.new()
        local a  = mock_scene("a")
        local b  = mock_scene("b")

        sm:switch(a)
        sm:switch(b)

        -- b is current and entered; a is held in _prev, not yet exited
        assert.are.equal(b,     sm.current)
        assert.are.equal(a,     sm._prev)
        assert.are.equal(1,     b.entered)
        assert.are.equal(0,     a.exited)
        assert.are.equal("out", sm._fade_state)
    end)

    it("on_exit fires after fade-out completes (alpha reaches 1)", function()
        local sm = SceneManager.new()
        local a  = mock_scene("a")
        local b  = mock_scene("b")

        sm:switch(a)
        sm:switch(b)

        -- Step past FADE_DURATION (0.3 s) in one large tick
        sm:update(0.4)

        assert.are.equal(1, a.exited)
        assert.is_nil(sm._prev)
        assert.are.equal("in", sm._fade_state)
    end)

    it("returns to idle after full fade cycle", function()
        local sm = SceneManager.new()
        local a  = mock_scene("a")
        local b  = mock_scene("b")

        sm:switch(a)
        sm:switch(b)

        sm:update(0.4)   -- completes fade-out, starts fade-in
        sm:update(0.4)   -- completes fade-in

        assert.are.equal("idle", sm._fade_state)
        assert.are.equal(0,      sm._fade_alpha)
    end)

end)
