-- Stub love.window.setFullscreen to track calls without side effects
local _last_fullscreen_arg = nil
love.window.setFullscreen = function(v) _last_fullscreen_arg = v end

local SettingsState = require("game/settings_state")

describe("SettingsState", function()
    it("new() initialises fullscreen to false", function()
        local s = SettingsState.new()
        assert.is_false(s.fullscreen)
    end)

    it("toggle_fullscreen flips fullscreen to true on first call", function()
        local s = SettingsState.new()
        s:toggle_fullscreen()
        assert.is_true(s.fullscreen)
    end)

    it("toggle_fullscreen flips fullscreen back to false on second call", function()
        local s = SettingsState.new()
        s:toggle_fullscreen()
        s:toggle_fullscreen()
        assert.is_false(s.fullscreen)
    end)

    it("toggle_fullscreen calls love.window.setFullscreen(true) on first call", function()
        local s = SettingsState.new()
        _last_fullscreen_arg = nil
        s:toggle_fullscreen()
        assert.is_true(_last_fullscreen_arg)
    end)

    it("toggle_fullscreen calls love.window.setFullscreen(false) on second call", function()
        local s = SettingsState.new()
        s:toggle_fullscreen()
        _last_fullscreen_arg = nil
        s:toggle_fullscreen()
        assert.is_false(_last_fullscreen_arg)
    end)
end)
