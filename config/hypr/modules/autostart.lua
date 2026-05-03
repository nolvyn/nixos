local c = require("modules.constants")

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p " .. c.home .. "/nixos/config/quickshell/bar")
    hl.exec_cmd("protonvpn-app")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("fcitx5")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprsunset")
    hl.exec_cmd("hyprshot")

    hl.exec_cmd("[workspace name:browser silent] " .. c.browser)
    hl.exec_cmd("[workspace name:vscode silent] code " .. c.home .. "/nixos")
    hl.exec_cmd("[workspace name:terminal silent] " .. c.terminal)
    hl.exec_cmd("[workspace name:spotify silent] spotify")
    hl.exec_cmd("[workspace name:discord silent] vesktop")

    if c.hostname == "WeebMachine" then
        hl.exec_cmd("[workspace name:steam silent] steam")
        hl.exec_cmd("[workspace name:games silent] heroic")
        hl.exec_cmd("[workspace name:games silent] sleepy-launcher")
        hl.exec_cmd("[workspace name:anime silent] vivaldi")
    elseif c.hostname == "MoeNote" then
        hl.exec_cmd("[workspace name:slack silent] slack")
    end
end)
