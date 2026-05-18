-- Map
-- Grid-based world layout. 40×30 cells, each cell 32×32 px (1280×960 world px).
-- Grid values: 1 = floor (walkable), 2 = wall (impassable for player; monster ignores).
-- Grid is indexed [row][col], both 1-based.
--
-- map.spawn      = { x, y }          world-space player start position
-- map.extraction = { x, y, radius }  world-space extraction zone centre and trigger radius
--
-- Coordinate helpers:
--   world_to_cell(wx, wy) → col, row
--   cell_to_world(col, row) → wx, wy  (top-left corner of cell)
--
-- draw() renders all tiles directly with love.graphics.rectangle — no Sprite overhead.
-- Floors: dark grey {0.15, 0.15, 0.15}. Walls: near-black {0.05, 0.05, 0.05}.

local Map = {}
Map.__index = Map

Map.CELL = 32
Map.COLS = 40
Map.ROWS = 30

function Map.new(grid, spawn, extraction)
    local self = setmetatable({}, Map)
    self.grid       = grid
    self.spawn      = spawn
    self.extraction = extraction
    return self
end

function Map:is_wall(col, row)
    if col < 1 or col > Map.COLS or row < 1 or row > Map.ROWS then
        return true
    end
    return self.grid[row][col] == 2
end

function Map:world_to_cell(wx, wy)
    local col = math.floor(wx / Map.CELL) + 1
    local row = math.floor(wy / Map.CELL) + 1
    return col, row
end

function Map:cell_to_world(col, row)
    return (col - 1) * Map.CELL, (row - 1) * Map.CELL
end

function Map:walkable_cells()
    local result = {}
    for row = 1, Map.ROWS do
        for col = 1, Map.COLS do
            if self.grid[row][col] == 1 then
                table.insert(result, { col = col, row = row })
            end
        end
    end
    return result
end

function Map:draw()
    local C = Map.CELL
    for row = 1, Map.ROWS do
        for col = 1, Map.COLS do
            if self.grid[row][col] == 2 then
                love.graphics.setColor(0.05, 0.05, 0.05, 1)
            else
                love.graphics.setColor(0.15, 0.15, 0.15, 1)
            end
            love.graphics.rectangle("fill", (col - 1) * C, (row - 1) * C, C, C)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Map
