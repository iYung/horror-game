local Scene = {}
Scene.__index = Scene

function Scene.new()
    return setmetatable({}, Scene)
end

function Scene:update(dt) end
function Scene:draw() end
function Scene:on_enter() end
function Scene:on_exit() end

return Scene
