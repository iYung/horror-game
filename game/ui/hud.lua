local HUD = {}
HUD.__index = HUD

local SLOT_SIZE   = 40
local SLOT_GAP    = 4
local SLOT_COUNT  = 5
local BAR_X       = 8
local BAR_Y       = 8

local COLOR_BORDER_INACTIVE = {0.3, 0.3, 0.3, 1}
local COLOR_BORDER_ACTIVE   = {1, 1, 1, 1}
local COLOR_BG              = {0.1, 0.1, 0.1, 1}
local COLOR_AMBER           = {1, 0.8, 0.2, 1}
local COLOR_WHITE           = {1, 1, 1, 1}

local EXTRACT_FONT  = love.graphics.newFont(22)
local SLOT_NUM_FONT = love.graphics.newFont(9)
local ITEM_FONT     = love.graphics.newFont(11)

local EXTRACT_RIGHT  = 16
local EXTRACT_BOTTOM = 16

local function format_time(seconds)
    local s = math.floor(seconds)
    local m = math.floor(s / 60)
    s = s % 60
    return string.format("%02d:%02d", m, s)
end

local function truncate_to_fit(text, font, max_w)
    if font:getWidth(text) <= max_w then
        return text
    end
    local truncated = text
    while #truncated > 0 and font:getWidth(truncated .. "..") > max_w do
        truncated = truncated:sub(1, -2)
    end
    return truncated .. ".."
end

function HUD.new(inventory, extraction, player, monster)
    local self = setmetatable({}, HUD)
    self.inventory  = inventory
    self.extraction = extraction
    self.player     = player
    self.monster    = monster
    return self
end

function HUD:draw()
    local prev_font = love.graphics.getFont()

    for i = 1, SLOT_COUNT do
        local x = BAR_X + (i - 1) * (SLOT_SIZE + SLOT_GAP)
        local y = BAR_Y

        love.graphics.setColor(COLOR_BG)
        love.graphics.rectangle("fill", x, y, SLOT_SIZE, SLOT_SIZE)

        if self.inventory:active_index() == i then
            love.graphics.setColor(COLOR_BORDER_ACTIVE)
        else
            love.graphics.setColor(COLOR_BORDER_INACTIVE)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, SLOT_SIZE, SLOT_SIZE)

        love.graphics.setFont(SLOT_NUM_FONT)
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.print(tostring(i), x + 3, y + 2)

        local item = self.inventory.slots[i]
        if item then
            local name = item.name or item.id or "?"
            local max_w = SLOT_SIZE - 6
            love.graphics.setFont(ITEM_FONT)
            local display = truncate_to_fit(name, ITEM_FONT, max_w)
            local tw = ITEM_FONT:getWidth(display)
            local th = ITEM_FONT:getHeight()
            love.graphics.setColor(COLOR_WHITE)
            love.graphics.print(display, x + (SLOT_SIZE - tw) / 2, y + (SLOT_SIZE - th) / 2)

            -- Adrenaline status overlay (active slot only)
            if item.id == "adrenaline" and self.inventory:active_index() == i then
                local status_label = nil
                local status_color = nil
                if item.boosting then
                    status_label = "BOOST"
                    status_color = COLOR_AMBER
                elseif item.on_cooldown and item.cooldown_timer then
                    local remaining = item.cooldown_timer.interval - item.cooldown_timer._t
                    status_label = "CD " .. math.ceil(remaining) .. "s"
                    status_color = {0.7, 0.2, 0.2, 1}
                end
                if status_label then
                    local sw = ITEM_FONT:getWidth(status_label)
                    local name_mid_y = y + (SLOT_SIZE - th) / 2
                    love.graphics.setColor(status_color)
                    love.graphics.print(status_label, x + (SLOT_SIZE - sw) / 2, name_mid_y + th)
                end
            end
        end
    end

    if self.extraction:is_active() then
        local remaining = self.extraction:time_remaining()
        local label = "EXTRACTING  " .. format_time(remaining)
        love.graphics.setFont(EXTRACT_FONT)
        local tw = EXTRACT_FONT:getWidth(label)
        local th = EXTRACT_FONT:getHeight()
        local ex = 1280 - EXTRACT_RIGHT - tw
        local ey = 720 - EXTRACT_BOTTOM - th
        love.graphics.setColor(COLOR_AMBER)
        love.graphics.print(label, ex, ey)
    elseif self.extraction:is_ready() then
        local t     = love.timer.getTime()
        local alpha = 0.6 + 0.4 * math.abs(math.sin(t * 3))
        local label = "RETURN TO EXTRACT"
        love.graphics.setFont(EXTRACT_FONT)
        local tw = EXTRACT_FONT:getWidth(label)
        local th = EXTRACT_FONT:getHeight()
        local ex = 1280 - EXTRACT_RIGHT - tw
        local ey = 720 - EXTRACT_BOTTOM - th
        love.graphics.setColor(1, 0.8, 0.2, alpha)
        love.graphics.print(label, ex, ey)
    elseif self.extraction.discovered then
        local t     = love.timer.getTime()
        local alpha = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * math.pi * 2))
        local label = "\xe2\x96\xbc EXTRACT"
        love.graphics.setFont(EXTRACT_FONT)
        local tw = EXTRACT_FONT:getWidth(label)
        local th = EXTRACT_FONT:getHeight()
        local ex = 1280 - EXTRACT_RIGHT - tw
        local ey = 720 - EXTRACT_BOTTOM - th
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(label, ex, ey)
    end

    -- Compass arrow: shown when player holds the compass
    if self.player then
        local item = self.player.inventory:active()
        if item and item.id == "compass" then
            local pc  = self.player:centre()
            local ez  = self.extraction._zone
            local dx  = ez.x - pc.x
            local dy  = ez.y - pc.y
            local world_angle    = math.atan2(dy, dx)
            local relative_angle = world_angle - self.player.angle
            love.graphics.push()
            love.graphics.translate(640, 680)
            love.graphics.rotate(relative_angle)
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.polygon("fill", 0, -18, -10, 10, 10, 10)
            love.graphics.pop()
        end
    end

    -- Adrenaline bar: shown at compass/tracker position when boosting or on cooldown
    if self.player then
        local item = self.player.inventory:active()
        if item and item.id == "adrenaline" then
            local bar_w = 80
            local bar_h = 8
            local bx    = 640 - bar_w / 2
            local by    = 676
            local progress, fill_color
            if item.boosting and item.boost_timer then
                progress   = (item.boost_timer.interval - item.boost_timer._t) / item.boost_timer.interval
                fill_color = COLOR_AMBER
            elseif item.on_cooldown and item.cooldown_timer then
                progress   = (item.cooldown_timer.interval - item.cooldown_timer._t) / item.cooldown_timer.interval
                fill_color = {0.7, 0.2, 0.2, 1}
            end
            if fill_color then
                love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
                love.graphics.rectangle("fill", bx, by, bar_w, bar_h)
                love.graphics.setColor(fill_color)
                love.graphics.rectangle("fill", bx, by, bar_w * progress, bar_h)
                love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", bx, by, bar_w, bar_h)
            end
        end
    end

    -- tracker arrow: shown when player holds tracker
    if self.player and self.monster then
        local item = self.player.inventory:active()
        if item and item.id == "tracker" then
            local pc  = self.player:centre()
            local dx  = self.monster.x - pc.x
            local dy  = self.monster.y - pc.y
            local world_angle    = math.atan2(dy, dx)
            local relative_angle = world_angle - self.player.angle
            love.graphics.push()
            love.graphics.translate(640, 680)
            love.graphics.rotate(relative_angle)
            love.graphics.setColor(1, 0.15, 0.15, 0.85)
            love.graphics.polygon("fill", 0, -18, -10, 10, 10, 10)
            love.graphics.pop()
        end
    end

    love.graphics.setFont(prev_font)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.setLineWidth(1)
end

return HUD
