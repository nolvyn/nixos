local c = require("modules.constants")

-- Fix some dragging issues with XWayland
hl.window_rule({
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({ match = { class = "vesktop" }, workspace = "name:discord" })
hl.window_rule({ match = { class = "spotify" }, workspace = "name:spotify" })
hl.window_rule({ match = { class = "steam" }, workspace = "name:steam" })
hl.window_rule({ match = { title = "Heroic Games Launcher" }, workspace = "name:games" })
hl.window_rule({ match = { class = "moe.launcher.sleepy-launcher" }, workspace = "name:games" })
hl.window_rule({ match = { class = "slack" }, workspace = "name:slack" })
hl.window_rule({ match = { class = "qbittorrent" }, workspace = "name:qbitorrent" })
hl.window_rule({ match = { class = "celluloid" }, workspace = "name:anime" })

-- Gaming Specific Rules
-- Force fullscreen for all games
hl.window_rule({ match = { class = "^steam_app_[0-9]+$" }, fullscreen = true })

-- Keep launcher/cover windows floating while the actual game stays fullscreen.
-- The explicit fullscreen state prevents the generic game rule above from
-- fullscreening them, and suppress_event prevents the launcher from requesting
-- fullscreen again during startup.
hl.window_rule({
    match            = {
        class         = "steam_app_4162040", -- Zenless Zone Zero
        initial_title = "^$",
    },
    fullscreen_state = "0 0",
    suppress_event   = "fullscreen",
    float            = true,
    center           = true,
})
hl.window_rule({
    match            = {
        class         = "steam_app_0", -- Heroic/non-Steam games, including Endfield
        initial_title = "^$",
    },
    fullscreen_state = "0 0",
    suppress_event   = "fullscreen",
    float            = true,
    center           = true,
})
hl.window_rule({
    match            = {
        class         = "steam_app_4162040", -- Zenless Zone Zero launcher
        initial_title = "^Zenless Zone Zero$",
    },
    fullscreen_state = "0 0",
    suppress_event   = "fullscreen",
    float            = true,
    center           = true,
})
hl.window_rule({
    match            = {
        class         = "steam_app_0", -- Arknights: Endfield launcher
        initial_title = "^Arknights: Endfield$",
    },
    fullscreen_state = "0 0",
    suppress_event   = "fullscreen",
    float            = true,
    center           = true,
})

-- Some Proton games create a launcher/cover window and reset fullscreen during handoff.
local fullscreen_game_classes = {
    ["steam_app_4508340"] = true, -- Neverness to Everness
    ["steam_app_3513350"] = true, -- Wuthering Waves
}
local fullscreen_game_until = {}
local fullscreen_game_timeout = 30

local function fullscreen_game_class(window)
    if window == nil then
        return nil
    end

    if fullscreen_game_classes[window.class] then
        return window.class
    end

    if fullscreen_game_classes[window.initial_class] then
        return window.initial_class
    end

    return nil
end

local function force_fullscreen_game(window)
    local class = fullscreen_game_class(window)
    if class == nil or os.time() > (fullscreen_game_until[class] or 0) then
        return
    end

    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "fullscreen",
        action = "set",
        window = window,
    }))
end

local function start_fullscreen_game_guard(window)
    local class = fullscreen_game_class(window)
    if class == nil then
        return
    end

    fullscreen_game_until[class] = os.time() + fullscreen_game_timeout
    force_fullscreen_game(window)
end

hl.on("window.open", start_fullscreen_game_guard)
hl.on("window.class", start_fullscreen_game_guard)
hl.on("window.fullscreen", force_fullscreen_game)

-- Keep Steam games on the Steam workspace, even if the mouse/pointer is on another
-- monitor when the game window appears. Numeric AppIDs cover every regular game
hl.window_rule({ match = { class = "^steam_app_[1-9][0-9]*$" }, workspace = "name:steam" })
hl.window_rule({ match = { class = "steam_app_0" }, workspace = "name:games" }) -- Heroic/non-Steam games

-- Auto-launch apps on empty workspace switch
hl.workspace_rule({ workspace = "name:slack", on_created_empty = "slack" })
hl.workspace_rule({ workspace = "name:spotify", on_created_empty = "spotify" })
hl.workspace_rule({ workspace = "name:steam", on_created_empty = "steam" })
hl.workspace_rule({ workspace = "name:games", on_created_empty = "heroic" })
hl.workspace_rule({ workspace = "name:discord", on_created_empty = "vesktop" })

-- Monitor Specific Rules
-- Main Monitor
hl.workspace_rule({ workspace = "1", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:steam", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:discord", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:slack", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:anime", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:qbitorrent", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:games", monitor = c.mainMonitor })
hl.workspace_rule({ workspace = "name:vscode", monitor = c.mainMonitor })

-- Vertical Monitor
hl.workspace_rule({ workspace = "name:terminal", monitor = c.verticalMonitor })
hl.workspace_rule({ workspace = "name:spotify", monitor = c.verticalMonitor })
hl.workspace_rule({ workspace = "10", monitor = c.verticalMonitor })
