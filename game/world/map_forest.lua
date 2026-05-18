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

-- 4×3 grid — mixed room and hallway sizes
--
-- Column layout (left→right):        Row layout (top→bottom):
--   Room A  [L=8]  cols  2–9           Room row 1  [M=6]  rows  2–7
--   Gap A–B [S=2]  cols 10–11          Gap 1–2     [M=4]  rows  8–11
--   Room B  [S=4]  cols 12–15          Room row 2  [S=4]  rows 12–15
--   Gap B–C [L=6]  cols 16–21          Gap 2–3     [L=6]  rows 16–21
--   Room C  [M=6]  cols 22–27          Room row 3  [L=8]  rows 22–29
--   Gap C–D [M=4]  cols 28–31
--   Room D  [L=8]  cols 32–39
--
-- Room sizes at intersections:
--   A1=8×6  B1=4×6  C1=6×6  D1=8×6
--   A2=8×4  B2=4×4  C2=6×4  D2=8×4
--   A3=8×8  B3=4×8  C3=6×8  D3=8×8

-- Row 1 rooms
fill_rect(grid, 2,  2,  9,  7,  1)  -- A1 (spawn)
fill_rect(grid, 12, 2,  15, 7,  1)  -- B1
fill_rect(grid, 22, 2,  27, 7,  1)  -- C1
fill_rect(grid, 32, 2,  39, 7,  1)  -- D1

-- Row 2 rooms
fill_rect(grid, 2,  12, 9,  15, 1)  -- A2
fill_rect(grid, 12, 12, 15, 15, 1)  -- B2
fill_rect(grid, 22, 12, 27, 15, 1)  -- C2
fill_rect(grid, 32, 12, 39, 15, 1)  -- D2

-- Row 3 rooms
fill_rect(grid, 2,  22, 9,  29, 1)  -- A3
fill_rect(grid, 12, 22, 15, 29, 1)  -- B3
fill_rect(grid, 22, 22, 27, 29, 1)  -- C3
fill_rect(grid, 32, 22, 39, 29, 1)  -- D3 (extraction)

-- Horizontal hallways — row 1 center row 4
fill_rect(grid, 10, 4,  11, 4,  1)  -- A1–B1  [S gap]
fill_rect(grid, 16, 4,  21, 4,  1)  -- B1–C1  [L gap]
fill_rect(grid, 28, 4,  31, 4,  1)  -- C1–D1  [M gap]

-- Horizontal hallways — row 2 center row 13
fill_rect(grid, 10, 13, 11, 13, 1)  -- A2–B2  [S gap]
fill_rect(grid, 16, 13, 21, 13, 1)  -- B2–C2  [L gap]
fill_rect(grid, 28, 13, 31, 13, 1)  -- C2–D2  [M gap]

-- Horizontal hallways — row 3 center row 25
fill_rect(grid, 10, 25, 11, 25, 1)  -- A3–B3  [S gap]
fill_rect(grid, 16, 25, 21, 25, 1)  -- B3–C3  [L gap]
fill_rect(grid, 28, 25, 31, 25, 1)  -- C3–D3  [M gap]

-- Vertical hallways — col A center col 5
fill_rect(grid, 5,  8,  5,  11, 1)  -- A1–A2  [M gap]
fill_rect(grid, 5,  16, 5,  21, 1)  -- A2–A3  [L gap]

-- Vertical hallways — col B center col 13
fill_rect(grid, 13, 8,  13, 11, 1)  -- B1–B2  [M gap]
fill_rect(grid, 13, 16, 13, 21, 1)  -- B2–B3  [L gap]

-- Vertical hallways — col C center col 24
fill_rect(grid, 24, 8,  24, 11, 1)  -- C1–C2  [M gap]
fill_rect(grid, 24, 16, 24, 21, 1)  -- C2–C3  [L gap]

-- Vertical hallways — col D center col 35
fill_rect(grid, 35, 8,  35, 11, 1)  -- D1–D2  [M gap]
fill_rect(grid, 35, 16, 35, 21, 1)  -- D2–D3  [L gap]

local spawn      = { x = 5  * Map.CELL, y = 4  * Map.CELL }
local extraction = { x = 35 * Map.CELL, y = 25 * Map.CELL, radius = 64 }

return Map.new(grid, spawn, extraction)
