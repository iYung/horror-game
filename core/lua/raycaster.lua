local SW = 1280
local SH = 720
local WALL_HEIGHT = 1.0

local Raycaster = {}
Raycaster.__index = Raycaster

function Raycaster.new()
    local self = setmetatable({}, Raycaster)
    self.z_buffer = {}
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
--     .sprites    (ignored — pass sprites to draw_sprites() instead)
function Raycaster:draw(map, px, py, angle, opts)
    opts = opts or {}
    local fov    = opts.fov or (math.pi / 3)
    local lights = opts.lights or {}

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
            self.z_buffer[col] = perp

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
            self.z_buffer[col] = math.huge
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- draw_sprites(sprites, px, py, angle, lights)
--   sprites : array of billboard tables, each:
--     .x, .y     : position in grid units (required)
--     .image     : Love2D Image object (required)
--     .scale     : billboard size multiplier (default 1.0)
--     .voffset   : world-unit vertical offset above floor (default 0, positive = up)
--     .flip_x    : mirror horizontally (default false)
--     .setup     : optional fn called before drawing this sprite (e.g. apply shader)
--     .teardown  : optional fn called after drawing this sprite
--   px, py  : player position in grid units
--   angle   : facing direction in radians
--   lights  : list of point lights { x, y, radius, intensity } (same format as draw())
function Raycaster:draw_sprites(sprites, px, py, angle, lights)
    if not sprites or #sprites == 0 then return end
    lights = lights or {}

    local dir_x    = math.cos(angle)
    local dir_y    = math.sin(angle)
    local half_tan = math.tan(math.pi / 3 / 2)
    local plane_x  = -dir_y * half_tan
    local plane_y  =  dir_x * half_tan
    local inv_det  = 1.0 / (plane_x * dir_y - dir_x * plane_y)

    -- Sort far-to-near so closer sprites draw over farther ones
    local sorted = {}
    for i, spr in ipairs(sprites) do
        local dx = spr.x - px
        local dy = spr.y - py
        sorted[#sorted + 1] = { spr = spr, dist2 = dx * dx + dy * dy, idx = i }
    end
    table.sort(sorted, function(a, b)
        if a.dist2 ~= b.dist2 then return a.dist2 > b.dist2 end
        return a.idx < b.idx
    end)

    for _, entry in ipairs(sorted) do
        local spr = entry.spr
        if spr.image then
            local dx = spr.x - px
            local dy = spr.y - py

            -- Project into camera space: tx = horizontal offset, tz = depth
            local tx = inv_det * ( dir_y   * dx - dir_x   * dy)
            local tz = inv_det * (-plane_y * dx + plane_x * dy)

            if tz > 0.05 then
                -- Fog brightness from point lights
                local b = 0
                for _, light in ipairs(lights) do
                    local ldx = spr.x - light.x
                    local ldy = spr.y - light.y
                    local dist = math.sqrt(ldx * ldx + ldy * ldy)
                    b = b + math.max(0, 1 - dist / light.radius) * light.intensity
                end
                b = math.min(b, 1)

                if b >= 0.01 then
                    local img = spr.image
                    local iw  = img:getWidth()
                    local ih  = img:getHeight()
                    local sc  = spr.scale or 1.0

                    local h  = math.min(SH * 2, math.floor(SH * WALL_HEIGHT / tz * sc))
                    local w  = math.floor(h * iw / ih)
                    local sx = math.floor(SW / 2 * (1 + tx / tz))
                    local x0 = sx - w / 2
                    local x1 = sx + w / 2

                    -- Vertical offset for sprites floating above the floor
                    local voff    = spr.voffset or 0
                    local y_center = SH / 2 + (WALL_HEIGHT / 2 - sc / 2 - voff) * (SH / tz)
                    local y0      = math.floor(y_center - h / 2)

                    local clip_y   = math.max(0, y0)
                    local clip_bot = math.min(SH, y0 + h)
                    local clip_h   = clip_bot - clip_y

                    local col_start = math.max(0, math.floor(x0))
                    local col_end   = math.min(SW - 1, math.floor(x1) - 1)

                    if clip_h > 0 and col_start <= col_end then
                        if spr.setup then spr.setup() end

                        love.graphics.setColor(b, b, b, 1)

                        -- Collect visible column runs and draw image once per run with scissor
                        local run_start = nil
                        for col = col_start, col_end do
                            local visible = tz < (self.z_buffer[col] or math.huge)
                            if visible and not run_start then
                                run_start = col
                            elseif not visible and run_start then
                                love.graphics.setScissor(run_start, clip_y, col - run_start, clip_h)
                                if spr.flip_x then
                                    love.graphics.draw(img, math.floor(x0) + w, y0, 0, -w / iw, h / ih)
                                else
                                    love.graphics.draw(img, math.floor(x0), y0, 0,  w / iw, h / ih)
                                end
                                run_start = nil
                            end
                        end
                        if run_start then
                            local rw = col_end - run_start + 1
                            love.graphics.setScissor(run_start, clip_y, rw, clip_h)
                            if spr.flip_x then
                                love.graphics.draw(img, math.floor(x0) + w, y0, 0, -w / iw, h / ih)
                            else
                                love.graphics.draw(img, math.floor(x0), y0, 0,  w / iw, h / ih)
                            end
                        end
                        love.graphics.setScissor()

                        if spr.teardown then spr.teardown() end
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Raycaster
