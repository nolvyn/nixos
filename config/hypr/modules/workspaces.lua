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
hl.window_rule({ match = { class = "^steam_app_" }, fullscreen = true })

-- Keep Curtain Games on Steam/Games Workspaces
hl.window_rule({ match = { class = "steam_app_2767030" }, workspace = "name:steam" }) -- Marvel Rivals
hl.window_rule({ match = { class = "steam_app_3513350" }, workspace = "name:steam" }) -- Wuthering Waves
hl.window_rule({ match = { class = "steam_app_0" }, workspace = "name:games" })       -- General

-- Auto-launch apps on empty workspace switch
hl.workspace_rule({ workspace = "name:slack", on_created_empty = "slack" })
hl.workspace_rule({ workspace = "name:spotify", on_created_empty = "spotify" })
hl.workspace_rule({ workspace = "name:steam", on_created_empty = "steam" })
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
