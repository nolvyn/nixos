local c = require("modules.constants")

hl.monitor({
    output = c.mainMonitor,
    mode = "highres@highrr",
    position = "0x0",
    scale = 1.875,
    bitdepth = 10,
})

hl.monitor({
    output = c.verticalMonitor,
    mode = "highres@60",
    position = "2048x0",
    scale = 1.33,
    transform = 3,
    bitdepth = 10,
})

hl.monitor({
    output = c.laptopScreen,
    mode = "highres@highrr",
    position = "0x0",
    scale = 1.25,
})
