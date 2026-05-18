local Drawer = require("core/lua/drawer")
local Camera = require("core/lua/camera")

local Scene = {}
Scene.__index = Scene

function Scene.new()
    local self  = setmetatable({}, Scene)
    self.drawer = Drawer.new()
    self.camera = Camera.new()
    return self
end

function Scene:update(dt) end

function Scene:draw()
    self.camera:attach()
    self.drawer:draw()
    self.camera:detach()
end

function Scene:on_enter() end

function Scene:on_exit()
    self.drawer:clear()
end

return Scene
