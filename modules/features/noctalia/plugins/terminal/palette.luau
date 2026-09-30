--!nonstrict
-- Builds the 256-color palette the helper installs on its libghostty-vt
-- terminal, from one Noctalia palette variant's `terminal` object.
--
-- The palette file is the shell's own color source, so the 16 ANSI colors and
-- the default foreground and background come straight from it. The rest is the
-- fixed xterm cube and gray ramp every terminal uses, which keeps a 24-bit
-- prompt and any truecolor output working the way they do in Ghostty.
--
-- tests/palette.luau checks the layout offline with plain `luau`.

local ANSI = { "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white" }
local CUBE = { 0, 95, 135, 175, 215, 255 }

local function push(out, r, g, b)
  out[#out + 1] = string.format("#%02x%02x%02x", r, g, b)
end

-- Returns the 256 palette entries, the default foreground, and the default
-- background, in the order the helper's `p` command expects.
local function build(colors)
  local out = {}
  for _, group in ipairs({ colors.normal, colors.bright }) do
    for _, name in ipairs(ANSI) do
      out[#out + 1] = group[name]
    end
  end
  for _, r in ipairs(CUBE) do
    for _, g in ipairs(CUBE) do
      for _, b in ipairs(CUBE) do
        push(out, r, g, b)
      end
    end
  end
  for step = 0, 23 do
    local level = 8 + step * 10
    push(out, level, level, level)
  end
  return out, colors.foreground, colors.background
end

return { build = build }
