local SimInput = {}
SimInput.__index = SimInput

function SimInput.new()
    local self    = setmetatable({}, SimInput)
    self._down    = {}
    self._pressed = {}
    self._inject  = {}
    return self
end

function SimInput:inject(actions)
    self._inject = actions
end

function SimInput:update()
    local new_pressed = {}
    local new_down    = {}
    for action, state in pairs(self._inject) do
        local down = state == true
        if down and not self._down[action] then
            new_pressed[action] = true
        end
        new_down[action] = down
    end
    -- actions present in _down last frame but absent from _inject are now false;
    -- rising-edge detection already handled above; no entry needed for released actions
    self._down    = new_down
    self._pressed = new_pressed
    self._inject  = {}
end

function SimInput:is_down(action)
    return self._down[action] == true
end

function SimInput:pressed(action)
    return self._pressed[action] == true
end

return SimInput
