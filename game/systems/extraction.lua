-- Extraction
-- Manages the end-of-run escape sequence.
-- The player must reach the extraction zone and fire the flare gun to start the 60 s timer.
-- Once started the timer cannot be cancelled. If the player is in the zone when it hits
-- zero, update() returns "extracted"; if not, it returns "failed".
--
-- `discovered` becomes true the first time the player enters the zone — used by HUD
-- to show the pulsing "▼ EXTRACT" indicator before the countdown begins.
--
-- Usage:
--   ex = Extraction.new(map)
--   ex:in_zone(player)          -- true if player centre is within map.extraction.radius
--   ex:try_start(player)        -- begin countdown if in zone; idempotent; returns bool
--   result = ex:update(dt, player)  -- "extracted", "failed", or nil
--   ex:is_active()              -- countdown running?
--   ex:time_remaining()         -- seconds left (0 if inactive)

local Timer = require("core/lua/timer")

local Extraction = {}
Extraction.__index = Extraction

Extraction.DURATION = 60

function Extraction.new(map)
    local self = setmetatable({}, Extraction)
    self._zone       = map.extraction
    self._timer      = nil
    self._elapsed    = 0
    self.discovered  = false
    return self
end

function Extraction:in_zone(player)
    local c  = player:centre()
    local z  = self._zone
    local dx = c.x - z.x
    local dy = c.y - z.y
    return (dx * dx + dy * dy) <= (z.radius * z.radius)
end

function Extraction:is_active()
    return self._timer ~= nil
end

function Extraction:time_remaining()
    if not self._timer then return 0 end
    return math.max(0, Extraction.DURATION - self._elapsed)
end

function Extraction:try_start(player)
    if self._timer then return true end
    if not self:in_zone(player) then return false end
    self._timer   = Timer.new(Extraction.DURATION)
    self._elapsed = 0
    return true
end

function Extraction:update(dt, player)
    if self:in_zone(player) and not self.discovered then
        self.discovered = true
    end

    if not self._timer then return nil end

    self._elapsed = self._elapsed + dt

    if self._timer:update(dt) then
        if self:in_zone(player) then
            return "extracted"
        else
            return "failed"
        end
    end

    return nil
end

return Extraction
