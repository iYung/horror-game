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

-- Top row of rooms
fill_rect(grid, 2,  2,  10, 8,  1)  -- room A (spawn here)
fill_rect(grid, 14, 2,  24, 8,  1)  -- room B
fill_rect(grid, 28, 2,  38, 8,  1)  -- room C

-- Corridors connecting top rooms
fill_rect(grid, 10, 4,  14, 6,  1)  -- A-B corridor
fill_rect(grid, 24, 4,  28, 6,  1)  -- B-C corridor

-- Middle row of rooms
fill_rect(grid, 2,  13, 10, 19, 1)  -- room D
fill_rect(grid, 14, 13, 24, 19, 1)  -- room E (wide centre)
fill_rect(grid, 28, 13, 38, 19, 1)  -- room F

-- Corridors connecting middle rooms
fill_rect(grid, 10, 15, 14, 17, 1)  -- D-E corridor
fill_rect(grid, 24, 15, 28, 17, 1)  -- E-F corridor

-- Bottom row of rooms
fill_rect(grid, 2,  23, 10, 29, 1)  -- room G
fill_rect(grid, 14, 23, 24, 29, 1)  -- room H
fill_rect(grid, 28, 23, 38, 29, 1)  -- room I (extraction here)

-- Corridors connecting bottom rooms
fill_rect(grid, 10, 25, 14, 27, 1)  -- G-H corridor
fill_rect(grid, 24, 25, 28, 27, 1)  -- H-I corridor

-- Vertical corridors connecting rows
fill_rect(grid, 4,  8,  6,  13, 1)  -- A-D
fill_rect(grid, 18, 8,  20, 13, 1)  -- B-E
fill_rect(grid, 32, 8,  34, 13, 1)  -- C-F
fill_rect(grid, 4,  19, 6,  23, 1)  -- D-G
fill_rect(grid, 18, 19, 20, 23, 1)  -- E-H
fill_rect(grid, 32, 19, 34, 23, 1)  -- F-I

local spawn      = { x = 5  * Map.CELL, y = 4  * Map.CELL }
local extraction = { x = 33 * Map.CELL, y = 26 * Map.CELL, radius = 64 }

return Map.new(grid, spawn, extraction)
