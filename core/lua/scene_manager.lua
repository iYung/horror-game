local SceneManager = {}
SceneManager.__index = SceneManager

function SceneManager.new()
    local self    = setmetatable({}, SceneManager)
    self.current  = nil
    return self
end

function SceneManager:switch(scene)
    if self.current then self.current:on_exit() end
    self.current = scene
    if self.current then self.current:on_enter() end
end

function SceneManager:update(dt)
    if self.current then self.current:update(dt) end
end

function SceneManager:draw()
    if self.current then self.current:draw() end
end

return SceneManager
