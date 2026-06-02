local SettingsMenu = {}
SettingsMenu.__index = SettingsMenu

local ITEMS = { "Fullscreen / Window", "Exit Settings", "Leave Game" }

local W       = 1280
local H       = 720
local BTN_W   = 300
local BTN_H   = 54
local BTN_X   = (W - BTN_W) / 2
local BTN_GAP = 74

local _btn_y0 = H / 2 - (#ITEMS - 1) * BTN_GAP / 2 - BTN_H / 2

function SettingsMenu.new(settings_state)
  local self = setmetatable({}, SettingsMenu)
  self._state        = settings_state
  self.is_open       = false
  self.selected      = 1
  self._opaque       = false
  self._prev_up      = false
  self._prev_down    = false
  self._prev_confirm = false
  self._prev_escape  = false
  self._img_btn     = love.graphics.newImage("assets/menu_btn.png")
  self._img_btn_sel = love.graphics.newImage("assets/menu_btn_selected.png")
  self._img_bg      = love.graphics.newImage("assets/settings_background.png")
  self._font_btn    = love.graphics.newFont(22)
  return self
end

function SettingsMenu:open(opaque)
  self.is_open  = true
  self._opaque  = opaque or false
  self.selected = 1
  self._prev_up      = love.keyboard.isDown("up") or love.keyboard.isDown("w")
  self._prev_down    = love.keyboard.isDown("down") or love.keyboard.isDown("s")
  self._prev_confirm = love.keyboard.isDown("e") or love.keyboard.isDown("f")
                    or love.keyboard.isDown("return") or love.keyboard.isDown("space")
  self._prev_escape  = love.keyboard.isDown("escape")
end

function SettingsMenu:close()
  self.is_open = false
end

function SettingsMenu:update(dt)
  local up      = love.keyboard.isDown("up")    or love.keyboard.isDown("w")
  local down    = love.keyboard.isDown("down")  or love.keyboard.isDown("s")
  local confirm = love.keyboard.isDown("e")      or love.keyboard.isDown("f")
               or love.keyboard.isDown("return") or love.keyboard.isDown("space")
  local escape  = love.keyboard.isDown("escape")

  if up and not self._prev_up then
    self.selected = ((self.selected - 2) % #ITEMS) + 1
  end

  if down and not self._prev_down then
    self.selected = (self.selected % #ITEMS) + 1
  end

  if confirm and not self._prev_confirm then
    self:_confirm()
  end

  if escape and not self._prev_escape then
    self:close()
  end

  self._prev_up      = up
  self._prev_down    = down
  self._prev_confirm = confirm
  self._prev_escape  = escape
end

function SettingsMenu:_confirm()
  if self.selected == 1 then
    self._state:toggle_fullscreen()
  elseif self.selected == 2 then
    self:close()
  elseif self.selected == 3 then
    love.event.quit()
  end
end

function SettingsMenu:draw()
  local prev_font = love.graphics.getFont()
  love.graphics.setFont(self._font_btn)

  if self._opaque then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._img_bg, 0, 0)
  else
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, W, H)
  end

  for i = 1, #ITEMS do
    local y   = _btn_y0 + (i - 1) * BTN_GAP
    local img = (i == self.selected) and self._img_btn_sel or self._img_btn
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, BTN_X, y)

    local label
    if i == 1 then
      label = self._state.fullscreen and "Window" or "Fullscreen"
    else
      label = ITEMS[i]
    end

    local ty = y + (BTN_H - self._font_btn:getHeight()) / 2
    love.graphics.printf(label, BTN_X, ty, BTN_W, "center")
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(prev_font)
end

function SettingsMenu:keypressed(key)
  return false
end

return SettingsMenu
