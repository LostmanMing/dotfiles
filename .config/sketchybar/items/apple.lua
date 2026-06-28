local colors = require("colors")
local icons = require("icons")

local M = {}
M.apple = sbar.add("item", {
  icon = {
    font = { size = 16.0 },
    string = icons.apple,
    color = colors.black,
    padding_left = 6,
    padding_right = 6,
    y_offset = 1,
  },
  label = { drawing = false },
  background = { drawing = false },
})
return M
