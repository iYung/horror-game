local Map = require("game/world/map")

local function make_grid()
    local grid = {}
    for row = 1, Map.ROWS do
        grid[row] = {}
        for col = 1, Map.COLS do
            grid[row][col] = 2
        end
    end
    return grid
end

local function fill_rect(grid, c1, r1, c2, r2, tile)
    for row = r1, r2 do
        for col = c1, c2 do
            grid[row][col] = tile
        end
    end
end

local grid = make_grid()

-- Cross-shaped main layout: wide horizontal + vertical halls
fill_rect(grid, 2,  13, 38, 17, 1)  -- horizontal main hall
fill_rect(grid, 18, 2,  22, 28, 1)  -- vertical main hall

-- Four corner rooms, all touching the main halls
fill_rect(grid, 2,  2,  16, 12, 1)  -- top-left room
fill_rect(grid, 24, 2,  38, 12, 1)  -- top-right room
fill_rect(grid, 2,  18, 16, 28, 1)  -- bottom-left room
fill_rect(grid, 24, 18, 38, 28, 1)  -- bottom-right room

local spawn      = { x = 4  * Map.CELL, y = 4  * Map.CELL }
local extraction = { x = 35 * Map.CELL, y = 25 * Map.CELL, radius = 64 }

return Map.new(grid, spawn, extraction)
