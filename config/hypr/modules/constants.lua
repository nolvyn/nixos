local home = os.getenv("HOME")
local hostname = io.open("/etc/hostname"):read("*l")
local wallpaper = home .. "/nixos/assets/wallpapers/fangyi.png"

return {
    browser         = "brave",
    fileManager     = "kitty -e yazi",
    home            = home,
    hostname        = hostname,
    menu            = "rofi -show drun",
    terminal        = "kitty",
    wallpaper       = wallpaper,

    mainMonitor     = "desc:Guangxi Century Innovation Display Electronics Co. Ltd 27M2U-D 0000000000000",
    verticalMonitor = "desc:Shenzhen KTC Technology Group H24T7 0x00000001",
    laptopScreen    = "desc:Lenovo Group Limited 0x41A8",
}
