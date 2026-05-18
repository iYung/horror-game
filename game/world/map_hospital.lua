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

-- 5×4 grid — mixed room and hallway sizes
--
-- Column layout (left→right):        Row layout (top→bottom):
--   Room A  [S=4]  cols  2– 5          Room row 1  [S=4]  rows  2– 5
--   Gap A–B [S=2]  cols  6– 7          Gap 1–2     [S=2]  rows  6– 7
--   Room B  [M=6]  cols  8–13          Room row 2  [M=5]  rows  8–12
--   Gap B–C [L=5]  cols 14–18          Gap 2–3     [M=3]  rows 13–15
--   Room C  [S=4]  cols 19–22          Room row 3  [L=6]  rows 16–21
--   Gap C–D [M=3]  cols 23–25          Gap 3–4     [S=2]  rows 22–23
--   Room D  [L=7]  cols 26–32          Room row 4  [M=5]  rows 24–28
--   Gap D–E [S=2]  cols 33–34
--   Room E  [M=5]  cols 35–39
--
-- Room sizes at intersections:
--   A1=4×4  B1=6×4  C1=4×4  D1=7×4  E1=5×4
--   A2=4×5  B2=6×5  C2=4×5  D2=7×5  E2=5×5
--   A3=4×6  B3=6×6  C3=4×6  D3=7×6  E3=5×6
--   A4=4×5  B4=6×5  C4=4×5  D4=7×5  E4=5×5

-- Row 1 rooms
fill_rect(grid, 2,  2,  5,  5,  1)  -- A1 (spawn)
fill_rect(grid, 8,  2,  13, 5,  1)  -- B1
fill_rect(grid, 19, 2,  22, 5,  1)  -- C1
fill_rect(grid, 26, 2,  32, 5,  1)  -- D1
fill_rect(grid, 35, 2,  39, 5,  1)  -- E1

-- Row 2 rooms
fill_rect(grid, 2,  8,  5,  12, 1)  -- A2
fill_rect(grid, 8,  8,  13, 12, 1)  -- B2
fill_rect(grid, 19, 8,  22, 12, 1)  -- C2
fill_rect(grid, 26, 8,  32, 12, 1)  -- D2
fill_rect(grid, 35, 8,  39, 12, 1)  -- E2

-- Row 3 rooms
fill_rect(grid, 2,  16, 5,  21, 1)  -- A3
fill_rect(grid, 8,  16, 13, 21, 1)  -- B3
fill_rect(grid, 19, 16, 22, 21, 1)  -- C3
fill_rect(grid, 26, 16, 32, 21, 1)  -- D3
fill_rect(grid, 35, 16, 39, 21, 1)  -- E3

-- Row 4 rooms
fill_rect(grid, 2,  24, 5,  28, 1)  -- A4
fill_rect(grid, 8,  24, 13, 28, 1)  -- B4
fill_rect(grid, 19, 24, 22, 28, 1)  -- C4
fill_rect(grid, 26, 24, 32, 28, 1)  -- D4
fill_rect(grid, 35, 24, 39, 28, 1)  -- E4 (extraction)

-- Horizontal hallways — row 1 center row 3
fill_rect(grid, 6,  3,  7,  3,  1)  -- A1–B1  [S gap]
fill_rect(grid, 14, 3,  18, 3,  1)  -- B1–C1  [L gap]
fill_rect(grid, 23, 3,  25, 3,  1)  -- C1–D1  [M gap]
fill_rect(grid, 33, 3,  34, 3,  1)  -- D1–E1  [S gap]

-- Horizontal hallways — row 2 center row 10
fill_rect(grid, 6,  10, 7,  10, 1)  -- A2–B2  [S gap]
fill_rect(grid, 14, 10, 18, 10, 1)  -- B2–C2  [L gap]
fill_rect(grid, 23, 10, 25, 10, 1)  -- C2–D2  [M gap]
fill_rect(grid, 33, 10, 34, 10, 1)  -- D2–E2  [S gap]

-- Horizontal hallways — row 3 center row 18
fill_rect(grid, 6,  18, 7,  18, 1)  -- A3–B3  [S gap]
fill_rect(grid, 14, 18, 18, 18, 1)  -- B3–C3  [L gap]
fill_rect(grid, 23, 18, 25, 18, 1)  -- C3–D3  [M gap]
fill_rect(grid, 33, 18, 34, 18, 1)  -- D3–E3  [S gap]

-- Horizontal hallways — row 4 center row 26
fill_rect(grid, 6,  26, 7,  26, 1)  -- A4–B4  [S gap]
fill_rect(grid, 14, 26, 18, 26, 1)  -- B4–C4  [L gap]
fill_rect(grid, 23, 26, 25, 26, 1)  -- C4–D4  [M gap]
fill_rect(grid, 33, 26, 34, 26, 1)  -- D4–E4  [S gap]

-- Vertical hallways — col A center col 3
fill_rect(grid, 3,  6,  3,  7,  1)  -- A1–A2  [S gap]
fill_rect(grid, 3,  13, 3,  15, 1)  -- A2–A3  [M gap]
fill_rect(grid, 3,  22, 3,  23, 1)  -- A3–A4  [S gap]

-- Vertical hallways — col B center col 10
fill_rect(grid, 10, 6,  10, 7,  1)  -- B1–B2  [S gap]
fill_rect(grid, 10, 13, 10, 15, 1)  -- B2–B3  [M gap]
fill_rect(grid, 10, 22, 10, 23, 1)  -- B3–B4  [S gap]

-- Vertical hallways — col C center col 20
fill_rect(grid, 20, 6,  20, 7,  1)  -- C1–C2  [S gap]
fill_rect(grid, 20, 13, 20, 15, 1)  -- C2–C3  [M gap]
fill_rect(grid, 20, 22, 20, 23, 1)  -- C3–C4  [S gap]

-- Vertical hallways — col D center col 29
fill_rect(grid, 29, 6,  29, 7,  1)  -- D1–D2  [S gap]
fill_rect(grid, 29, 13, 29, 15, 1)  -- D2–D3  [M gap]
fill_rect(grid, 29, 22, 29, 23, 1)  -- D3–D4  [S gap]

-- Vertical hallways — col E center col 37
fill_rect(grid, 37, 6,  37, 7,  1)  -- E1–E2  [S gap]
fill_rect(grid, 37, 13, 37, 15, 1)  -- E2–E3  [M gap]
fill_rect(grid, 37, 22, 37, 23, 1)  -- E3–E4  [S gap]

local spawn      = { x = 2  * Map.CELL, y = 2  * Map.CELL }
local extraction = { x = 37 * Map.CELL, y = 26 * Map.CELL, radius = 64 }

return Map.new(grid, spawn, extraction)
