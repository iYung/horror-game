-- Pathfinder
-- A* on the map grid. 4-directional movement, Manhattan distance heuristic.
-- Used by monster WANDER/ALERTED/SEARCH states to pick destinations.
-- The monster does NOT use pathfinding for CHASE — it moves straight toward the player.
-- The monster also ignores wall collision during movement; pathfinding only selects goals.
--
-- Capped at 2000 expanded nodes to prevent hangs on degenerate inputs.
-- Returns nil if start/goal is a wall or no path exists within the cap.
--
-- Usage:
--   pf = Pathfinder.new(map)
--   path = pf:find(start_col, start_row, goal_col, goal_row)
--   -- path is { {col,row}, … } from start to goal inclusive, or nil

local Pathfinder = {}
Pathfinder.__index = Pathfinder

local NODE_CAP = 2000

local DIRS = {
    { 0, -1 },
    { 0,  1 },
    { -1, 0 },
    { 1,  0 },
}

function Pathfinder.new(map)
    local self = setmetatable({}, Pathfinder)
    self.map   = map
    return self
end

local function heuristic(ac, ar, bc, br)
    return math.abs(ac - bc) + math.abs(ar - br)
end

local function node_key(col, row)
    return col * 1000 + row
end

local function heap_push(heap, node)
    table.insert(heap, node)
    local i = #heap
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].f > heap[i].f then
            heap[parent], heap[i] = heap[i], heap[parent]
            i = parent
        else
            break
        end
    end
end

local function heap_pop(heap)
    local top = heap[1]
    local n   = #heap
    heap[1]   = heap[n]
    heap[n]   = nil
    n = n - 1
    local i = 1
    while true do
        local left  = 2 * i
        local right = 2 * i + 1
        local least = i
        if left <= n and heap[left].f < heap[least].f then
            least = left
        end
        if right <= n and heap[right].f < heap[least].f then
            least = right
        end
        if least == i then break end
        heap[i], heap[least] = heap[least], heap[i]
        i = least
    end
    return top
end

function Pathfinder:find(start_col, start_row, goal_col, goal_row)
    local map = self.map

    if map:is_wall(start_col, start_row) or map:is_wall(goal_col, goal_row) then
        return nil
    end

    if start_col == goal_col and start_row == goal_row then
        return { { col = start_col, row = start_row } }
    end

    local open    = {}
    local g_score = {}
    local came    = {}
    local closed  = {}
    local count   = 0

    local sk = node_key(start_col, start_row)
    g_score[sk] = 0

    heap_push(open, { col = start_col, row = start_row,
        f = heuristic(start_col, start_row, goal_col, goal_row) })

    while #open > 0 do
        local current = heap_pop(open)
        local cc      = current.col
        local cr      = current.row
        local ck      = node_key(cc, cr)

        if not closed[ck] then
            closed[ck] = true
            count      = count + 1

            if count > NODE_CAP then return nil end

            if cc == goal_col and cr == goal_row then
                local path = {}
                local node = { col = cc, row = cr, key = ck }
                while node do
                    table.insert(path, 1, { col = node.col, row = node.row })
                    node = came[node.key]
                end
                return path
            end

            local cg = g_score[ck] or math.huge

            for _, d in ipairs(DIRS) do
                local nc = cc + d[1]
                local nr = cr + d[2]
                local nk = node_key(nc, nr)

                if not map:is_wall(nc, nr) and not closed[nk] then
                    local tentative = cg + 1
                    if tentative < (g_score[nk] or math.huge) then
                        g_score[nk] = tentative
                        came[nk]    = { col = cc, row = cr, key = ck }
                        heap_push(open, { col = nc, row = nr,
                            f = tentative + heuristic(nc, nr, goal_col, goal_row) })
                    end
                end
            end
        end
    end

    return nil
end

return Pathfinder
