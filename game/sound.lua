-- Sound
-- Module-level singleton for SFX and music playback.
-- All functions are no-ops when love.audio is nil (headless test mode).
--
-- SFX: static sources loaded once, cloned on each play call.
-- Music: streaming looping sources; supports immediate play and volume fading.
--
-- Usage:
--   local Sound = require("game/sound")
--   Sound.load()                          -- call once after love.load
--   Sound.update(dt)                      -- call each frame to advance fades
--   Sound.play("monster_step")            -- fire-and-forget SFX
--   Sound.play_music("ambient")           -- start a music track
--   Sound.fade_music("chase", 1, 1.5)     -- fade chase music to full over 1.5 s
--   Sound.stop_music("ambient")           -- stop and rewind

local Sound = {}

-- ── Internal state ────────────────────────────────────────────────────────────

local _sfx   = {}   -- name → love.Source (static, prototype)
local _music = {}   -- name → love.Source (stream, looping)
local _fades = {}   -- name → { target = number, rate = number }

local _sfx_volume   = 1
local _music_volume = 1

-- ── Configuration ─────────────────────────────────────────────────────────────

local SFX_NAMES = {
    "monster_step",
    "item_pickup",
    "item_use",
    "extraction_start",
    "extraction_ready",
    "player_death",
    "win",
    "lose",
}

local MUSIC_NAMES = { "menu", "ambient", "chase" }

-- ── Load ──────────────────────────────────────────────────────────────────────

function Sound.load()
    if not love.audio then return end

    -- SFX (static sources)
    for _, name in ipairs(SFX_NAMES) do
        local path = "assets/sounds/" .. name .. ".wav"
        if love.filesystem.getInfo(path) then
            local src = love.audio.newSource(path, "static")
            src:setVolume(_sfx_volume)
            _sfx[name] = src
        end
    end

    -- Music tracks (streaming, looping); try .wav then .mp3
    for _, name in ipairs(MUSIC_NAMES) do
        local wav  = "assets/music/" .. name .. ".wav"
        local mp3  = "assets/music/" .. name .. ".mp3"
        local path = nil
        if love.filesystem.getInfo(wav) then
            path = wav
        elseif love.filesystem.getInfo(mp3) then
            path = mp3
        end
        if path then
            local src = love.audio.newSource(path, "stream")
            src:setLooping(true)
            src:setVolume(_music_volume)
            _music[name] = src
        end
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function Sound.update(dt)
    if not love.audio then return end

    for name, fade in pairs(_fades) do
        local src = _music[name]
        if src then
            local vol = src:getVolume()
            local step = fade.rate * dt
            -- Move toward target
            if fade.rate > 0 then
                vol = math.min(vol + step, fade.target)
            else
                vol = math.max(vol + step, fade.target)
            end
            vol = math.max(0, math.min(1, vol))
            src:setVolume(vol)
            -- Remove entry once target is reached
            if vol == fade.target then
                _fades[name] = nil
            end
        else
            _fades[name] = nil
        end
    end
end

-- ── SFX ───────────────────────────────────────────────────────────────────────

function Sound.play(name, volume)
    if not love.audio then return end
    local src = _sfx[name]
    if not src then return end
    local clone = src:clone()
    if volume then clone:setVolume(math.max(0, math.min(1, volume * _sfx_volume))) end
    clone:play()
end

function Sound.set_sfx_volume(v)
    if not love.audio then return end
    _sfx_volume = math.max(0, math.min(1, v))
    for _, src in pairs(_sfx) do
        src:setVolume(_sfx_volume)
    end
end

-- ── Music ─────────────────────────────────────────────────────────────────────

function Sound.set_music_volume(v)
    if not love.audio then return end
    _music_volume = math.max(0, math.min(1, v))
    for _, src in pairs(_music) do
        src:setVolume(_music_volume)
    end
end

function Sound.play_music(name)
    if not love.audio then return end
    local src = _music[name]
    if not src then return end
    src:setVolume(_music_volume)
    src:play()
end

function Sound.fade_music(name, target, secs)
    if not love.audio then return end
    local src = _music[name]
    if not src then return end
    target = math.max(0, math.min(1, target))
    if secs <= 0 then
        src:setVolume(target)
        _fades[name] = nil
        return
    end
    local current = src:getVolume()
    local delta   = target - current
    if delta == 0 then
        _fades[name] = nil
        return
    end
    -- rate is signed: positive means volume is increasing
    _fades[name] = { target = target, rate = delta / secs }
end

function Sound.stop_music(name)
    if not love.audio then return end
    local src = _music[name]
    if not src then return end
    _fades[name] = nil
    src:stop()
end

function Sound.is_music_playing(name)
    if not love.audio then return false end
    local src = _music[name]
    if not src then return false end
    return src:isPlaying()
end

return Sound
