-- Stubs must be in place BEFORE requiring settings_menu (module-level code runs on first require)
local _font_stub = { getHeight = function() return 20 end }
love.graphics.newImage    = function(path) return {} end
love.graphics.newFont     = function(size) return _font_stub end
love.graphics.getFont     = function() return _font_stub end
love.graphics.setFont     = function() end
love.graphics.setColor    = function() end
love.graphics.draw        = function() end
love.graphics.rectangle   = function() end
love.graphics.print       = function() end
love.graphics.printf      = function() end
love.window.setFullscreen = function(v) end
love.keyboard.isDown      = function() return false end

local _quit_called = false
love.event.quit = function() _quit_called = true end

local SettingsState = require("game/settings_state")
local SettingsMenu  = require("game/scenes/settings_menu")

-- Helper: open menu cleanly with no keys held
local function open_clean(menu)
    love.keyboard.isDown = function() return false end
    menu:open(false)
end

-- Helper: simulate pressing a key for one frame then releasing
local function sim_key(menu, key)
    love.keyboard.isDown = function(k) return k == key end
    menu:update(0)
    love.keyboard.isDown = function() return false end
    menu:update(0)
end

describe("SettingsMenu", function()
    it("is_open starts false", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        assert.is_false(m.is_open)
    end)

    it("open() sets is_open to true", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        assert.is_true(m.is_open)
    end)

    it("open() resets selected to 1", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        m.selected = 3
        open_clean(m)
        assert.are.equal(1, m.selected)
    end)

    it("close() sets is_open to false", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        m:close()
        assert.is_false(m.is_open)
    end)

    it("escape key closes the menu", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        sim_key(m, "escape")
        assert.is_false(m.is_open)
    end)

    it("down key moves selection from 1 to 2", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        sim_key(m, "down")
        assert.are.equal(2, m.selected)
    end)

    it("down wraps from 3 back to 1", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        sim_key(m, "down") -- 1->2
        sim_key(m, "down") -- 2->3
        sim_key(m, "down") -- 3->1
        assert.are.equal(1, m.selected)
    end)

    it("up wraps from 1 to 3", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        sim_key(m, "up")
        assert.are.equal(3, m.selected)
    end)

    it("confirming item 1 calls toggle_fullscreen", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        -- selected is already 1 after open_clean
        assert.is_false(s.fullscreen)
        sim_key(m, "f")
        assert.is_true(s.fullscreen)
        -- menu stays open after fullscreen toggle
        assert.is_true(m.is_open)
    end)

    it("confirming item 2 closes the menu", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        sim_key(m, "down") -- move to item 2
        sim_key(m, "f")
        assert.is_false(m.is_open)
    end)

    it("confirming item 3 calls love.event.quit", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        open_clean(m)
        sim_key(m, "down") -- 1->2
        sim_key(m, "down") -- 2->3
        _quit_called = false
        sim_key(m, "f")
        assert.is_true(_quit_called)
    end)

    it("keypressed returns false", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        assert.is_false(m:keypressed("escape"))
    end)

    it("key held at open time does not fire on first update", function()
        local s = SettingsState.new()
        local m = SettingsMenu.new(s)
        -- hold escape while opening — should NOT close on first update
        love.keyboard.isDown = function(k) return k == "escape" end
        m:open(false)
        -- _prev_escape is now true (snapshotted)
        m:update(0)
        assert.is_true(m.is_open)
    end)
end)
