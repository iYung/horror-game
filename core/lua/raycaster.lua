local SW = 1280
local SH = 720

local Raycaster = {}
Raycaster.__index = Raycaster

function Raycaster.new()
    local self = setmetatable({}, Raycaster)
    self._zbuf = {}
    return self
end

-- draw(map, px, py, angle, opts)
--   map       : object with is_wall(col, row) — 1-indexed integers
--   px, py    : player position in grid units (1-indexed float)
--   angle     : facing direction in radians
--   opts      : optional table
--     .fov        number   horizontal FOV in radians (default π/3)
--     .lights     table    list of point lights, each:
--                            { x, y, radius, intensity }
--                          x/y in 1-indexed grid units; radius in cells
--                          if nil/empty, everything is pitch black
--     .sprites    table    list of billboard sprites, each:
--                            { x, y, size=1, color={r,g,b,a} }
--                          x/y in grid units; size scales height relative to wall height
function Raycaster:draw(map, px, py, angle, opts)
    opts = opts or {}
    local fov     = opts.fov or (math.pi / 3)
    local lights  = opts.lights or {}
    local sprites = opts.sprites or {}

    local dir_x    = math.cos(angle)
    local dir_y    = math.sin(angle)
    -- Camera plane perpendicular to direction, half-width = tan(fov/2)
    local half_tan = math.tan(fov / 2)
    local plane_x  = -dir_y * half_tan
    local plane_y  =  dir_x * half_tan

    -- Floor — flat colour, drawn once before the wall pass
    love.graphics.setColor(0.10, 0.08, 0.08, 1)
    love.graphics.rectangle("fill", 0, SH / 2, SW, SH / 2)

    -- Walls — DDA per column, build z-buffer
    for col = 0, SW - 1 do
        local cam_x = 2 * col / SW - 1   -- -1 (left edge) to +1 (right edge)
        local rdx   = dir_x + plane_x * cam_x
        local rdy   = dir_y + plane_y * cam_x

        local mx = math.floor(px)
        local my = math.floor(py)

        local ddx = math.abs(rdx) < 1e-10 and 1e10 or math.abs(1 / rdx)
        local ddy = math.abs(rdy) < 1e-10 and 1e10 or math.abs(1 / rdy)

        local sx, sdx, sy, sdy
        if rdx < 0 then sx = -1; sdx = (px - mx)     * ddx
        else             sx =  1; sdx = (mx + 1 - px) * ddx end
        if rdy < 0 then sy = -1; sdy = (py - my)     * ddy
        else             sy =  1; sdy = (my + 1 - py) * ddy end

        local hit, side = false, 0
        for _ = 1, 64 do
            if sdx < sdy then sdx = sdx + ddx; mx = mx + sx; side = 0
            else              sdy = sdy + ddy; my = my + sy; side = 1 end
            if map:is_wall(mx, my) then hit = true; break end
        end

        if hit then
            local perp = side == 0 and (sdx - ddx) or (sdy - ddy)
            self._zbuf[col] = perp

            local brightness = 0
            for _, light in ipairs(lights) do
                local hx = mx + 0.5
                local hy = my + 0.5
                local dx = hx - light.x
                local dy = hy - light.y
                local dist = math.sqrt(dx*dx + dy*dy)
                brightness = brightness + math.max(0, 1 - dist / light.radius) * light.intensity
            end
            brightness = math.min(brightness, 1)

            local br = (side == 1 and 0.45 or 0.7) * brightness
            local h  = math.floor(SH / perp)
            local y1 = math.floor(SH / 2 - h / 2)
            local y2 = math.floor(SH / 2 + h / 2)
            love.graphics.setColor(br * 0.55, br * 0.5, br * 0.7, 1)
            love.graphics.line(col, y1, col, y2)
        else
            self._zbuf[col] = math.huge
        end
    end

    -- Sprites (billboards) — sorted far-to-near so closer sprites draw over farther ones
    if #sprites > 0 then
        table.sort(sprites, function(a, b)
            local adx, ady = a.x - px, a.y - py
            local bdx, bdy = b.x - px, b.y - py
            return (adx * adx + ady * ady) > (bdx * bdx + bdy * bdy)
        end)

        -- Inverse of the [plane | dir] 2×2 matrix for camera-space transform
        local inv_det = 1.0 / (plane_x * dir_y - dir_x * plane_y)

        for _, sp in ipairs(sprites) do
            local dx = sp.x - px
            local dy = sp.y - py

            -- Project into camera space: tx = horizontal offset, tz = depth
            local tx = inv_det * ( dir_y   * dx - dir_x   * dy)
            local tz = inv_det * (-plane_y * dx + plane_x * dy)

            if tz > 0.05 then
                local sp_brightness = 0
                for _, light in ipairs(lights) do
                    local dx = sp.x - light.x
                    local dy = sp.y - light.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    sp_brightness = sp_brightness + math.max(0, 1 - dist / light.radius) * light.intensity
                end
                sp_brightness = math.min(sp_brightness, 1)
                local fog = sp_brightness
                if fog > 0.01 then
                    local size   = sp.size or 1.0
                    local h_half = math.floor(SH / tz * size / 2)
                    local sy1    = math.floor(SH / 2 - h_half)
                    local sy2    = math.floor(SH / 2 + h_half)
                    local sx_cen = math.floor(SW / 2 * (1 + tx / tz))
                    local sx1    = sx_cen - h_half
                    local sx2    = sx_cen + h_half

                    local c = sp.color or {1, 1, 1, 1}
                    love.graphics.setColor(c[1] * fog, c[2] * fog, c[3] * fog, c[4] or 1)

                    for x = math.max(0, sx1), math.min(SW - 1, sx2) do
                        if (self._zbuf[x] or math.huge) > tz then
                            love.graphics.line(x, sy1, x, sy2)
                        end
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Raycaster
