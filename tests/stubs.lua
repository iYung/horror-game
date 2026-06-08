-- tests/stubs.lua
-- Install no-op replacements for love.graphics, love.keyboard, and
-- love.filesystem before any game module loads in headless (no-display) mode.

local function noop() end

local stub_image = {
    getWidth      = function() return 1 end,
    getHeight     = function() return 1 end,
    getDimensions = function() return 1, 1 end,
    setFilter     = noop,
}

local graphics = {
    -- Drawing primitives
    setColor        = noop,
    rectangle       = noop,
    line            = noop,
    draw            = noop,
    polygon         = noop,
    print           = noop,
    printf          = noop,
    clear           = noop,

    -- Transform stack
    push            = noop,
    pop             = noop,
    translate       = noop,
    scale           = noop,
    rotate          = noop,

    -- State
    setScissor      = noop,
    setShader       = noop,
    setBlendMode    = noop,
    setDefaultFilter = noop,
    setFont         = noop,
    setLineWidth    = noop,

    -- Queries
    getDimensions   = function() return 1280, 720 end,
    getFont         = function() return stub_image end,

    -- Resource constructors
    newShader       = function() return { send = noop } end,
    newFont         = function() return stub_image end,
    newImage        = function() return stub_image end,
}

-- Catch-all: any other unlisted key returns noop (or a new-resource factory
-- for names that start with "new").
setmetatable(graphics, {
    __index = function(_, key)
        if type(key) == "string" and key:sub(1, 3) == "new" then
            return function()
                return {
                    getWidth      = function() return 1 end,
                    getHeight     = function() return 1 end,
                    getDimensions = function() return 1, 1 end,
                    setFilter     = noop,
                }
            end
        end
        return noop
    end,
})

love.graphics = graphics

love.keyboard.isDown      = function() return false end
love.filesystem.getInfo   = function() return nil end
