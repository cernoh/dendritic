-- dendritic-leetcode/browser.lua
-- Headed-browser login: opens the system Chromium-family browser on an
-- isolated profile, lets the user log in normally, and polls the
-- `dendritic-leet-login` helper (Python stdlib, reads the profile's
-- cookie SQLite) until LEETCODE_SESSION + csrftoken appear.
-- No Electron/bundled browser: reuses Brave/Chromium already on the host.
-- Callers must check M.available() first; on headless hosts or without
-- the helper, login.lua falls back to the cookie-paste form.

local M = {}

local LOGIN_URL = "https://leetcode.com/accounts/login/"
local HELPER = "dendritic-leet-login"
local BROWSERS = {
  "brave",
  "brave-browser",
  "chromium",
  "chromium-browser",
  "google-chrome",
  "google-chrome-stable",
}

local POLL_MS = 2000
local MAX_POLLS = 150 -- ~5 minutes, then time out

local pending = nil -- active login attempt, or nil

local function notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("[dendritic-leetcode] " .. msg, level)
end

local function profile_dir()
  return vim.fn.stdpath("cache") .. "/dendritic-leetcode/browser-profile"
end

local function executable(cmd)
  return vim.fn.executable(cmd) == 1
end

local function find_browser()
  for _, b in ipairs(BROWSERS) do
    if executable(b) then
      return b
    end
  end
  return nil
end

local function has_display()
  local env = vim.env
  return env.DISPLAY ~= nil and env.DISPLAY ~= "" or env.WAYLAND_DISPLAY ~= nil and env.WAYLAND_DISPLAY ~= ""
end

function M.available()
  return executable(HELPER) and find_browser() ~= nil and has_display()
end

function M.cancel()
  if pending then
    pending.cancelled = true
    pending = nil
    notify("Browser login cancelled", vim.log.levels.WARN)
  end
end

local function finish(raw, cb)
  local state = pending
  pending = nil
  if not state or state.cancelled then
    if cb then
      pcall(cb, false, "cancelled")
    end
    return
  end
  -- Hand the raw header to leetcode.nvim's own validated setter.
  local ok, cookie = pcall(require, "leetcode.cache.cookie")
  if not ok then
    if cb then
      pcall(cb, false, "leetcode.nvim not loaded")
    end
    return
  end
  local err = cookie.set(raw)
  if err then
    notify("Sign-in failed: " .. err, vim.log.levels.ERROR)
    if cb then
      pcall(cb, false, err)
    end
    return
  end
  notify("Sign-in successful — browser login captured cookies", vim.log.levels.INFO)
  local ok2, cmd = pcall(require, "leetcode.command")
  if ok2 and cmd.start_user_session then
    cmd.start_user_session()
  end
  if cb then
    pcall(cb, true, nil)
  end
end

local function poll(cb)
  local state = pending
  if not state or state.cancelled then
    return
  end
  if state.tries >= MAX_POLLS then
    pending = nil
    notify("Browser login timed out after ~5 minutes", vim.log.levels.WARN)
    if cb then
      pcall(cb, false, "timed out waiting for login")
    end
    return
  end
  state.tries = state.tries + 1
  vim.system({ HELPER, "extract", "--profile-dir", state.profile }, { text = true }, function(res)
    vim.schedule(function()
      if not pending or pending.cancelled then
        return
      end
      local out = res.stdout and vim.trim(res.stdout) or ""
      if res.code == 0 and out:match("LEETCODE_SESSION=") and out:match("csrftoken=") then
        finish(out, cb)
      else
        vim.defer_fn(function()
          poll(cb)
        end, POLL_MS)
      end
    end)
  end)
end

---Launch the browser and resolve cb(true) once cookies are captured.
---@param cb fun(ok: boolean, err?: string)
function M.login(cb)
  if pending then
    notify("Login already in progress (:DendriticLeetCancel to stop)", vim.log.levels.WARN)
    return
  end
  if not executable(HELPER) then
    if cb then
      pcall(cb, false, "helper not installed")
    end
    return
  end
  local browser = find_browser()
  if not browser then
    if cb then
      pcall(cb, false, "no Chromium-family browser found")
    end
    return
  end
  if not has_display() then
    if cb then
      pcall(cb, false, "no display for browser login")
    end
    return
  end

  local profile = profile_dir()
  vim.fn.mkdir(profile, "p")
  local job = vim.fn.jobstart({
    browser,
    "--user-data-dir=" .. profile,
    "--no-first-run",
    "--no-default-browser-check",
    LOGIN_URL,
  }, { detach = true })
  if job <= 0 then
    if cb then
      pcall(cb, false, "could not launch " .. browser)
    end
    return
  end

  pending = { tries = 0, profile = profile, cancelled = false }
  notify("Browser opened — log in at leetcode.com; cookies are captured automatically (:DendriticLeetCancel to stop)")
  poll(cb)
end

return M
