local HeadlessInput = {}
HeadlessInput.__index = HeadlessInput

function HeadlessInput.new()
    local self     = setmetatable({}, HeadlessInput)
    self._down     = {}
    self._pressed  = {}
    self._tapped   = {}  -- actions queued by press(); auto-released on next update()
    self._holding  = {}  -- actions currently in hold mode; prevents pressed re-trigger
    return self
end

-- Single-frame tap: down+pressed this frame, both auto-cleared by the next :update().
function HeadlessInput:press(action)
    self._down[action]    = true
    self._pressed[action] = true
    self._tapped[action]  = true
end

-- Holds action down indefinitely. pressed fires only on the first frame hold() is called
-- for this action (before any :update()). Subsequent :hold() calls keep down alive without
-- re-triggering pressed. Use :press() to fire a new rising edge while held.
function HeadlessInput:hold(action)
    self._down[action] = true
    if not self._holding[action] then
        self._holding[action] = true
        self._pressed[action] = true
    end
end

-- Clears all state for the given action.
function HeadlessInput:release(action)
    self._down[action]    = nil
    self._pressed[action] = nil
    self._tapped[action]  = nil
    self._holding[action] = nil
end

-- Advances one frame: clears all pressed flags and auto-releases tapped actions.
-- Call once at the start of each frame before driving the scene.
function HeadlessInput:update()
    for action in pairs(self._pressed) do
        self._pressed[action] = nil
    end
    for action in pairs(self._tapped) do
        self._down[action]   = nil
        self._tapped[action] = nil
    end
end

function HeadlessInput:is_down(action)
    return self._down[action] == true
end

function HeadlessInput:pressed(action)
    return self._pressed[action] == true
end

return HeadlessInput
