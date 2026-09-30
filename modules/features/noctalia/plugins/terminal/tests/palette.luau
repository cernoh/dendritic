--!nonstrict
-- Offline check for palette.luau: the 16 ANSI slots come from the theme in
-- order, and the 240 slots after them are the xterm cube and gray ramp.
--
--   nix shell nixpkgs#luau --command luau plugins/terminal/tests/palette.luau

local palette = require("../palette")

local colors = {
  foreground = "#ece0cd",
  background = "#1e1813",
  normal = {
    black = "#2a231a",
    red = "#c56a5a",
    green = "#8f9a6a",
    yellow = "#d9b06a",
    blue = "#8a9bb0",
    magenta = "#c9a3a0",
    cyan = "#7d9a8e",
    white = "#c9b79c",
  },
  bright = {
    black = "#5f4d3a",
    red = "#d98470",
    green = "#a9b47f",
    yellow = "#e8c98a",
    blue = "#a3b3c6",
    magenta = "#dcb9c0",
    cyan = "#96b0a5",
    white = "#f3e9d8",
  },
}

local entries, foreground, background = palette.build(colors)

assert(#entries == 256, "expected 256 palette entries, got " .. tostring(#entries))
assert(foreground == colors.foreground, "default foreground was not passed through")
assert(background == colors.background, "default background was not passed through")

for index, name in ipairs({ "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white" }) do
  assert(entries[index] == colors.normal[name], "normal " .. name .. " is out of order")
  assert(entries[index + 8] == colors.bright[name], "bright " .. name .. " is out of order")
end

-- 16 + 6*6*6 cube + 24 grays.
assert(entries[17] == "#000000", "cube does not start at black")
assert(entries[232] == "#ffffff", "cube does not end at white")
assert(entries[233] == "#080808", "gray ramp does not start at 8")
assert(entries[256] == "#eeeeee", "gray ramp does not end at 238")

for _, entry in ipairs(entries) do
  assert(string.match(entry, "^#%x%x%x%x%x%x$") ~= nil, "malformed color " .. tostring(entry))
end

print("palette: 256 entries, 16 from the theme, cube and ramp in place")
