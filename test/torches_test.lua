-- torches_test.lua
-- Data-integrity and math tests for the wall-torch lighting system.
-- No love.graphics calls — safe for headless mode.

local Map = require("game/world/map")

-- true if the cell itself is floor, or any 4-neighbour is floor.
-- Covers both "torch on wall adjacent to room" and "torch on topmost floor row".
local function near_room(map, col, row)
    if not map:is_wall(col, row) then return true end
    local ns = { {col-1,row}, {col+1,row}, {col,row-1}, {col,row+1} }
    for _, n in ipairs(ns) do
        if not map:is_wall(n[1], n[2]) then return true end
    end
    return false
end

-- Inline copy of the raycaster point-light formula — tests it as a spec.
local function brightness(lights, hx, hy)
    local b = 0
    for _, light in ipairs(lights) do
        local dx   = hx - light.x
        local dy   = hy - light.y
        local dist = math.sqrt(dx * dx + dy * dy)
        b = b + math.max(0, 1 - dist / light.radius) * light.intensity
    end
    return math.min(b, 1)
end

-- ──────────────────────────────────────────────────────────
-- Point-light formula
-- ──────────────────────────────────────────────────────────

describe("Point-light brightness formula", function()

    it("at the light centre brightness equals intensity", function()
        local lights = { { x=5, y=5, radius=6, intensity=1.0 } }
        assert.are.equal(1.0, brightness(lights, 5, 5))
    end)

    it("at exactly the radius edge brightness is zero", function()
        local lights = { { x=5, y=5, radius=6, intensity=1.0 } }
        assert.are.equal(0.0, brightness(lights, 5, 11))  -- 6 cells south
    end)

    it("beyond the radius brightness is zero", function()
        local lights = { { x=5, y=5, radius=6, intensity=1.0 } }
        assert.are.equal(0.0, brightness(lights, 5, 12))  -- 7 cells south
    end)

    it("no lights means pitch black", function()
        assert.are.equal(0.0, brightness({}, 10, 10))
    end)

    it("two overlapping lights accumulate and clamp to 1", function()
        local lights = {
            { x=5, y=5, radius=6, intensity=1.0 },
            { x=5, y=5, radius=6, intensity=1.0 },
        }
        assert.are.equal(1.0, brightness(lights, 5, 5))  -- clamped from 2.0
    end)

    it("partial intensity scales brightness linearly", function()
        local lights = { { x=5, y=5, radius=4, intensity=0.5 } }
        -- At centre: contribution = (1 - 0/4) * 0.5 = 0.5
        assert.are.equal(0.5, brightness(lights, 5, 5))
    end)

end)

-- ──────────────────────────────────────────────────────────
-- Forest map torch data
-- ──────────────────────────────────────────────────────────

describe("Map torches — forest", function()
    local map = require("game/world/map_forest")

    it("has 12 torches", function()
        assert.are.equal(12, #map.torches)
    end)

    it("every torch has col and row fields", function()
        for i, t in ipairs(map.torches) do
            assert.is_not_nil(t.col, "torch " .. i .. " missing col")
            assert.is_not_nil(t.row, "torch " .. i .. " missing row")
        end
    end)

    it("every torch is within map bounds", function()
        for i, t in ipairs(map.torches) do
            assert.is_true(t.col >= 1 and t.col <= Map.COLS,
                "torch " .. i .. " col=" .. t.col .. " out of bounds")
            assert.is_true(t.row >= 1 and t.row <= Map.ROWS,
                "torch " .. i .. " row=" .. t.row .. " out of bounds")
        end
    end)

    it("every torch is near a room", function()
        for i, t in ipairs(map.torches) do
            assert.is_true(near_room(map, t.col, t.row),
                "torch " .. i .. " col=" .. t.col .. " row=" .. t.row .. " not near any room")
        end
    end)

    it("no two torches share a position", function()
        local seen = {}
        for i, t in ipairs(map.torches) do
            local key = t.col .. "," .. t.row
            assert.is_nil(seen[key],
                "duplicate torch " .. i .. " at col=" .. t.col .. " row=" .. t.row)
            seen[key] = true
        end
    end)

end)

-- ──────────────────────────────────────────────────────────
-- Hospital map torch data
-- ──────────────────────────────────────────────────────────

describe("Map torches — hospital", function()
    local map = require("game/world/map_hospital")

    it("has 20 torches", function()
        assert.are.equal(20, #map.torches)
    end)

    it("every torch has col and row fields", function()
        for i, t in ipairs(map.torches) do
            assert.is_not_nil(t.col, "torch " .. i .. " missing col")
            assert.is_not_nil(t.row, "torch " .. i .. " missing row")
        end
    end)

    it("every torch is within map bounds", function()
        for i, t in ipairs(map.torches) do
            assert.is_true(t.col >= 1 and t.col <= Map.COLS,
                "torch " .. i .. " col=" .. t.col .. " out of bounds")
            assert.is_true(t.row >= 1 and t.row <= Map.ROWS,
                "torch " .. i .. " row=" .. t.row .. " out of bounds")
        end
    end)

    it("every torch is near a room", function()
        for i, t in ipairs(map.torches) do
            assert.is_true(near_room(map, t.col, t.row),
                "torch " .. i .. " col=" .. t.col .. " row=" .. t.row .. " not near any room")
        end
    end)

    it("no two torches share a position", function()
        local seen = {}
        for i, t in ipairs(map.torches) do
            local key = t.col .. "," .. t.row
            assert.is_nil(seen[key],
                "duplicate torch " .. i .. " at col=" .. t.col .. " row=" .. t.row)
            seen[key] = true
        end
    end)

end)

-- ──────────────────────────────────────────────────────────
-- Simulation integration
-- ──────────────────────────────────────────────────────────

describe("Simulation — torch data accessible", function()
    local Simulation = require("game/simulation")

    local function make_config(map_id)
        return { map_id = map_id, budget = 0, loadout_item = nil, monster_traits = {} }
    end

    it("forest sim exposes 12 torches via map", function()
        local sim = Simulation.new(make_config("forest"))
        assert.is_not_nil(sim.map.torches)
        assert.are.equal(12, #sim.map.torches)
    end)

    it("hospital sim exposes 20 torches via map", function()
        local sim = Simulation.new(make_config("hospital"))
        assert.is_not_nil(sim.map.torches)
        assert.are.equal(20, #sim.map.torches)
    end)

end)
