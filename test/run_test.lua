-- run_test.lua
-- Busted tests for the headless Simulation class.
-- Run via the Love2D headless runner which injects busted globals.

local Simulation = require("game/simulation")
local Items      = require("game/data/items")

local function make_config(overrides)
    local cfg = {
        map_id         = "forest",
        budget         = 0,
        loadout_item   = nil,
        monster_traits = {},
    }
    for k, v in pairs(overrides or {}) do cfg[k] = v end
    return cfg
end

describe("Simulation", function()

    it("monster kills player when overlapping", function()
        local sim = Simulation.new(make_config())

        -- Move monster on top of player pixel centre (grid unit 6.5,5.5 → px 192,160)
        sim.monster.x = 192
        sim.monster.y = 160

        local state = sim:step(1 / 60)

        assert.are.equal("death", state.outcome)
    end)

    it("player extracts after completing countdown in zone", function()
        local sim = Simulation.new(make_config())

        -- Move player to extraction zone (pixel 1120,800 → grid unit 35.5,25.5)
        sim.player.x = 35.5
        sim.player.y = 25.5

        -- Move monster away and disable kill callback — this test is about extraction,
        -- not kill detection; a random wander into the player would be a false failure
        sim.monster.x      = 192
        sim.monster.y      = 160
        sim.monster.on_kill = nil

        -- Start extraction countdown; player is now in zone so this must return true
        local started = sim.extraction:try_start(sim.player)
        assert.is_true(started)

        local state = sim:run_until(function(s)
            return s.outcome ~= nil
        end, { max_seconds = 70 })

        assert.are.equal("extracted", state.outcome)
    end)

    it("hearing trait alerts monster when player moves nearby", function()
        local sim = Simulation.new(make_config({ monster_traits = { "hearing" } }))

        -- 96 px north of player centre (192,160), well inside the 8-cell (256 px) hearing range
        sim.monster.x = 192
        sim.monster.y = 64

        local state = sim:step(1 / 60, { fwd = true })

        assert.are.equal("alerted", state.monster.state)
    end)

    it("hearing trait does not alert when player is still", function()
        local sim = Simulation.new(make_config({ monster_traits = { "hearing" } }))

        sim.monster.x   = 192
        sim.monster.y   = 64
        sim.monster.on_kill = nil  -- prevent kill from ending the run if monster wanders close

        local state = sim:run_until(function(s)
            return s.monster.state ~= "wander"
        end, { max_seconds = 2 })

        assert.are.equal("wander", state.monster.state)
    end)

    it("sight trait chases player in line of sight", function()
        local sim = Simulation.new(make_config({ monster_traits = { "sight" } }))

        -- 64 px east of player centre in the same room, unobstructed horizontal LOS
        sim.monster.x = 256
        sim.monster.y = 160

        local state = sim:step(1 / 60)

        assert.are.equal("chase", state.monster.state)
    end)

    it("sight trait chases player via flashlight glow without LOS", function()
        -- Player starts at spawn (forest map top-left) with a flashlight.
        -- Monster starts at extraction (bottom-right) — far away with walls between,
        -- so no direct LOS. Turning the flashlight on should trigger the glow branch
        -- and immediately set monster state to chase.
        local sim = Simulation.new(make_config({
            monster_traits = { "sight" },
            loadout_item   = Items.new("flashlight"),
        }))

        -- Confirm no LOS by default: monster should be in wander after one still frame
        local pre = sim:step(1 / 60)
        assert.are.equal("wander", pre.monster.state)

        -- Now toggle the flashlight on with a single use press
        local state = sim:step(1 / 60, { use = true })

        assert.are.equal("chase", state.monster.state)
    end)

    it("smell trait alerts monster within 3 seconds", function()
        -- Monster starts far from player; no LOS, player not moving.
        -- Only the smell timer (fires at 2.5 s) should trigger alerted.
        local sim = Simulation.new(make_config({ monster_traits = { "smell" } }))

        local state = sim:run_until(function(s)
            return s.monster.state == "alerted"
        end, { max_seconds = 4 })

        assert.are.equal("alerted", state.monster.state)
    end)

    it("compass item can be held without errors", function()
        local run_config = make_config({
            budget         = 3,
            map_id         = "forest",
            monster_traits = {},
            loadout_item   = Items.new("compass"),
        })
        local sim = Simulation.new(run_config)

        local state
        for _ = 1, 10 do
            state = sim:step(1 / 60)
        end

        assert.is_not_nil(state)
    end)

    it("tracker item can be held without errors", function()
        local run_config = make_config({
            budget         = 1,
            map_id         = "forest",
            monster_traits = {},
            loadout_item   = Items.new("tracker"),
        })
        local sim = Simulation.new(run_config)

        local state
        for _ = 1, 10 do
            state = sim:step(1 / 60)
        end

        assert.is_not_nil(state)
    end)

end)
