require("modules.animations")
require("modules.autostart")
require("modules.decorations")
require("modules.input")
require("modules.keybinds")
require("modules.monitors")
require("modules.workspaces")

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("GDK_SCALE", "2")

hl.config({
    ecosystem = {
        no_update_news = true,
    },
    -- Fix Blurry Electron Apps
    xwayland = {
        force_zero_scaling = true,
    },
    general = {
        gaps_in                 = 2,
        gaps_out                = 4,
        border_size             = 1,
        resize_on_border        = true,
        ["col.active_border"]   = { colors = { "rgba(cba6f7ff)", "rgba(89b4faff)" }, angle = 45 },
        ["col.inactive_border"] = "rgba(6c7086ff)",
        layout                  = "dwindle",
    },
    dwindle = {
        preserve_split = true,
    },
})
