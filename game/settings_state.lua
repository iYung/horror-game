local SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
    return setmetatable({ fullscreen = false }, SettingsState)
end

function SettingsState:toggle_fullscreen()
    self.fullscreen = not self.fullscreen
    love.window.setFullscreen(self.fullscreen)
end

return SettingsState
