-- CameraShake
-- Produces a random screen-jitter offset that decays to zero over DECAY_TIME seconds.
-- The monster calls trigger() on its step timer; RunScene applies the result as a
-- love.graphics.translate() INSIDE camera:attach()/detach() so the shake is purely
-- visual and does not affect the camera's tracked position (which would cause drift).
--
-- Caller sets magnitude based on monster distance:
--   > 10 cells → 0   (no trigger)
--   6–10       → 1
--   3–6        → 3
--   < 3        → 6
--
-- Usage:
--   shake = CameraShake.new()
--   shake:trigger(magnitude)      -- start/restart a shake
--   ox, oy = shake:update(dt)     -- advance decay, returns current offset
--   ox, oy = shake:offset()       -- read offset without advancing (use one or the other)

local CameraShake = {}
CameraShake.__index = CameraShake

local DECAY_TIME = 0.15

function CameraShake.new()
    local self      = setmetatable({}, CameraShake)
    self.magnitude  = 0
    self.remaining  = 0
    return self
end

function CameraShake:trigger(magnitude)
    self.magnitude = magnitude
    self.remaining = DECAY_TIME
end

function CameraShake:update(dt)
    if self.remaining <= 0 then
        self.magnitude = 0
        self.remaining = 0
        return
    end
    self.remaining = self.remaining - dt
    if self.remaining < 0 then
        self.remaining = 0
    end
    self.magnitude = self.magnitude * (self.remaining / DECAY_TIME)
end

function CameraShake:offset()
    if self.magnitude == 0 then
        return 0, 0
    end
    local m  = self.magnitude
    local ox = love.math.random() * 2 * m - m
    local oy = love.math.random() * 2 * m - m
    return ox, oy
end

return CameraShake
