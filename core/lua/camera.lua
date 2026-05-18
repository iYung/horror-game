local LOGICAL_W, LOGICAL_H = 1280, 720

local Camera = {}
Camera.__index = Camera

function Camera.new(x, y)
    local self = setmetatable({}, Camera)
    self.x     = x or 0
    self.y     = y or 0
    self.zoom  = 1.0
    return self
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(LOGICAL_W / 2, LOGICAL_H / 2)
    love.graphics.scale(self.zoom)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
    love.graphics.pop()
end

-- lerp: 0 = instant follow, 1 = no movement
function Camera:follow(target, lerp)
    lerp   = lerp or 0
    local f = 1 - lerp
    self.x  = self.x + (target.x - self.x) * f
    self.y  = self.y + (target.y - self.y) * f
end


return Camera
