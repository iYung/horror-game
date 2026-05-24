-- Items
-- Item definitions and factory. Always use items.new(id) to get a fresh instance —
-- never share item tables between inventory slots or runs.
--
-- Each item has:
--   id      string    unique identifier
--   name    string    display name
--   value   number    budget cost; item only spawns if value <= run budget
--   use_fn  function  called when player presses F with item active
--
-- Flashlight: value=1. Toggled on/off each F press. 120 s battery total regardless of
--             on/off state. While on, monster Sight detects the glow without LOS.
--             Extends fog range to 14 cells while on.
-- Flare gun:  value=0 (always spawns). use_fn returns "extract". RunScene intercepts
--             this string and calls extraction:try_start only if player is in zone.
-- Compass:    value=3. Passive item — no use_fn. While held as the active item,
--             the HUD draws a directional arrow pointing toward the extraction zone.
-- Tracker:    value=1. Passive item — no use_fn. While held as the active item,
--             the HUD draws a directional arrow pointing toward the monster.

local Timer = require("core/lua/timer")

local items = {}

local definitions = {
    flashlight = {
        id       = "flashlight",
        name     = "Flashlight",
        value    = 1,
        duration = 120,
    },
    flare_gun = {
        id    = "flare_gun",
        name  = "Flare Gun",
        value = 0,
    },
    compass    = { id = "compass",  name = "Compass",  value = 3 },
    tracker    = { id = "tracker",  name = "Tracker",  value = 1 },
    adrenaline = {
        id               = "adrenaline",
        name             = "Adrenaline Shot",
        value            = 2,
        boost_duration   = 5,
        boost_mult       = 1.75,
        cooldown_duration = 20,
    },
}

local function make_flashlight()
    local self = {}
    for k, v in pairs(definitions.flashlight) do self[k] = v end
    self.active  = false
    self.timer   = nil
    self.elapsed = 0
    self.on      = false

    self.use_fn = function(player, world)
        if self.timer == nil then
            self.timer = Timer.new(self.duration)
            self.active = true
        end
        self.on = not self.on
    end

    self.update = function(dt, inventory)
        if self.timer == nil then return end
        self.elapsed = self.elapsed + dt
        if self.timer:update(dt) then
            self.on     = false
            self.active = false
            inventory:remove_item_by_ref(self)
        end
    end

    return self
end

local function make_flare_gun()
    local self = {}
    for k, v in pairs(definitions.flare_gun) do self[k] = v end
    self.used = false

    self.use_fn = function(player, world)
        if self.used then return nil end
        self.used = true
        return "extract"
    end

    return self
end

local function make_compass()
    local self = {}
    for k, v in pairs(definitions.compass) do self[k] = v end
    return self
end

local function make_tracker()
    local self = {}
    for k, v in pairs(definitions.tracker) do self[k] = v end
    return self
end

local function make_adrenaline()
    local self = {}
    for k, v in pairs(definitions.adrenaline) do self[k] = v end
    self.boosting       = false
    self.on_cooldown    = false
    self.boost_timer    = nil
    self.cooldown_timer = nil
    self.speed_mult     = 1.0

    self.use_fn = function(player, world)
        if self.boosting or self.on_cooldown then return end
        self.boosting    = true
        self.speed_mult  = self.boost_mult
        self.boost_timer = Timer.new(self.boost_duration)
    end

    self.update = function(dt)
        if self.boosting and self.boost_timer then
            if self.boost_timer:update(dt) then
                self.boosting       = false
                self.speed_mult     = 1.0
                self.boost_timer    = nil
                self.on_cooldown    = true
                self.cooldown_timer = Timer.new(self.cooldown_duration)
            end
        end
        if self.on_cooldown and self.cooldown_timer then
            if self.cooldown_timer:update(dt) then
                self.on_cooldown    = false
                self.cooldown_timer = nil
            end
        end
    end

    return self
end

local factories = {
    flashlight = make_flashlight,
    flare_gun  = make_flare_gun,
    compass    = make_compass,
    tracker    = make_tracker,
    adrenaline = make_adrenaline,
}

function items.new(id)
    local factory = factories[id]
    assert(factory, "unknown item id: " .. tostring(id))
    return factory()
end

return items
