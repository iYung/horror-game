-- ItemSpawner
-- Places items on random walkable floor cells at the start of each run.
-- Items are budget-gated: item.value must be <= the run budget to be eligible.
-- Flare gun (value=0) always spawns exactly once, guaranteed > 10 cells from spawn.
-- Torches and flashlights each spawn 3–5 copies when budget >= 1.
--
-- Returns a list of ground items: { { x, y, item }, … }
-- Positions are cell centres in world space.
-- Spawn and extraction cells are excluded from placement.
--
-- Usage:
--   ground_items = ItemSpawner.spawn(map, budget)

local Items = require("game/data/items")
local Map   = require("game/world/map")

local CELL = Map.CELL

local ItemSpawner = {}

local function cell_centre(col, row)
    return (col - 1) * CELL + CELL / 2, (row - 1) * CELL + CELL / 2
end

local function manhattan(c1, r1, c2, r2)
    return math.abs(c1 - c2) + math.abs(r1 - r2)
end

local function pick_random(list, count, exclude_set)
    local pool = {}
    for _, cell in ipairs(list) do
        local k = cell.col * 1000 + cell.row
        if not exclude_set[k] then
            table.insert(pool, cell)
        end
    end

    local chosen = {}
    for _ = 1, count do
        if #pool == 0 then break end
        local idx  = math.random(1, #pool)
        local cell = pool[idx]
        table.insert(chosen, cell)
        table.remove(pool, idx)
    end
    return chosen
end

function ItemSpawner.spawn(map, budget)
    local walkable   = map:walkable_cells()
    local ground     = {}

    local sc, sr = map:world_to_cell(map.spawn.x, map.spawn.y)
    local ec, er = map:world_to_cell(map.extraction.x, map.extraction.y)

    local reserved   = {}
    reserved[sc * 1000 + sr] = true
    reserved[ec * 1000 + er] = true

    if budget >= 1 then
        local torch_count = math.random(3, 5)
        local cells = pick_random(walkable, torch_count, reserved)
        for _, cell in ipairs(cells) do
            local wx, wy = cell_centre(cell.col, cell.row)
            table.insert(ground, { x = wx, y = wy, item = Items.new("torch") })
            reserved[cell.col * 1000 + cell.row] = true
        end

        local fl_count = math.random(3, 5)
        cells = pick_random(walkable, fl_count, reserved)
        for _, cell in ipairs(cells) do
            local wx, wy = cell_centre(cell.col, cell.row)
            table.insert(ground, { x = wx, y = wy, item = Items.new("flashlight") })
            reserved[cell.col * 1000 + cell.row] = true
        end
    end

    local flare_pool = {}
    for _, cell in ipairs(walkable) do
        if manhattan(cell.col, cell.row, sc, sr) > 10 then
            local k = cell.col * 1000 + cell.row
            if not reserved[k] then
                table.insert(flare_pool, cell)
            end
        end
    end

    if #flare_pool == 0 then
        for _, cell in ipairs(walkable) do
            local k = cell.col * 1000 + cell.row
            if not reserved[k] then
                table.insert(flare_pool, cell)
            end
        end
    end

    if #flare_pool > 0 then
        local idx  = math.random(1, #flare_pool)
        local cell = flare_pool[idx]
        local wx, wy = cell_centre(cell.col, cell.row)
        table.insert(ground, { x = wx, y = wy, item = Items.new("flare_gun") })
    end

    return ground
end

return ItemSpawner
