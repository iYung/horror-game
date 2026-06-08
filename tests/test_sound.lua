local Sound = require("game/sound")

describe("Sound (headless)", function()
    it("load() does not crash when love.audio is nil", function()
        Sound.load()
    end)

    it("update() does not crash when love.audio is nil", function()
        Sound.update(1/60)
    end)

    it("play() does not crash for a known SFX name", function()
        Sound.play("monster_step")
    end)

    it("play() does not crash for an unknown SFX name", function()
        Sound.play("nonexistent_sfx")
    end)

    it("play_music() does not crash when love.audio is nil", function()
        Sound.play_music("ambient")
    end)

    it("fade_music() does not crash when love.audio is nil", function()
        Sound.fade_music("chase", 1, 1.5)
    end)

    it("stop_music() does not crash when love.audio is nil", function()
        Sound.stop_music("ambient")
    end)

    it("is_music_playing() returns false when love.audio is nil", function()
        assert.is_false(Sound.is_music_playing("ambient"))
    end)

    it("set_sfx_volume() does not crash when love.audio is nil", function()
        Sound.set_sfx_volume(0.5)
    end)

    it("set_music_volume() does not crash when love.audio is nil", function()
        Sound.set_music_volume(0.5)
    end)
end)
