local Map = {}
Map.__index = Map

function Map.new(grid)
    return setmetatable({ grid = grid }, Map)
end

function Map:is_wall(x, y)
    local row = self.grid[y]
    return row and row[x] and row[x] ~= 0
end

function Map:cell(x, y)
    local row = self.grid[y]
    return row and row[x] or 0
end

function Map:width()
    return #(self.grid[1] or {})
end

function Map:height()
    return #self.grid
end

return Map
