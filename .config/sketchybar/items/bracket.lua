local colors = require("colors")
local apple = require("items.apple")
local workspaces = require("items.spaces_aero_dev")
local battery = require("items.widgets.battery")
local wifi = require("items.widgets.wifi")
local cpu_and_temp = require("items.widgets.cpu_and_temp")
local cal = require("items.calendar")

local cap = {
  background = { color = colors.bg3, border_color = colors.bg3, border_width = 1, height = 30, corner_radius = 10 },
}

-- Right
sbar.add("bracket", {
  cpu_and_temp.cpu.name, cpu_and_temp.temp.name,
  wifi.wifi.name, wifi.wifi_up.name, wifi.wifi_down.name,
}, cap)
sbar.add("bracket", { battery.battery.name }, cap)
sbar.add("bracket", { cal.cal.name }, cap)

-- Left: Apple 独立胶囊
sbar.add("bracket", { apple.apple.name }, cap)

-- Left: Workspaces
sbar.add("bracket", {
  workspaces[1].name, workspaces[2].name, workspaces[3].name, workspaces[4].name,
  workspaces[5].name, workspaces[6].name, workspaces[7].name, workspaces[8].name,
  workspaces[9].name, workspaces[10].name,
}, cap)
