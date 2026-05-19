function love.conf(t)
    t.window.title = "NIGHTFALL"

    local headless = false
    for _, v in ipairs(arg or {}) do
        if v == "--headless" then
            headless = true
            break
        end
    end

    if headless then
        t.window = false
        t.audio.enable = false
    end
end
