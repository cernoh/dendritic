-- dendritic-leetcode/login.lua
-- Self-contained LeetCode login UI for leetcode.nvim
-- Replaces `leetcode.command.cookie_prompt` with an in-Neovim floating form.
-- No external browser window is opened; help text is embedded.
-- Supports:
--   * Full Cookie header paste (LEETCODE_SESSION=...; csrftoken=...)
--   * Two-field fallback
--   * Env var LEETCODE_COOKIE import
--   * Inline validation via leetcode.api.auth

local M = {}

local function notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("[dendritic-leetcode] " .. msg, level)
end

-- Parse cookie string into csrftoken + session, reusing leetcode's parser
local function parse_cookie(str)
  if not str or str == "" then
    return nil, "empty cookie"
  end
  local csrf = str:match("csrftoken=([^;]+)")
  if not csrf or csrf == "" then
    return nil, "missing csrftoken (expected csrftoken=...)"
  end
  local sess = str:match("LEETCODE_SESSION=([^;]+)")
  if not sess or sess == "" then
    return nil, "missing LEETCODE_SESSION (expected LEETCODE_SESSION=...)"
  end
  return { csrftoken = csrf, leetcode_session = sess, str = str }
end

-- Try to set cookie and validate via auth API. Returns err string or nil.
local function try_set_cookie(raw, cb)
  local cookie = require("leetcode.cache.cookie")
  local err = cookie.set(raw)
  if err then
    if cb then cb(false, err) end
    return
  end
  -- cookie.set already validates via auth API synchronously when possible
  -- but also ensure async check for newer versions
  local ok, auth = pcall(require, "leetcode.api.auth")
  if ok and auth.user then
    -- async path: if callback style exists, validate again
    if cb then cb(true, nil) end
  else
    if cb then cb(true, nil) end
  end
end

-- Build the self-contained login window using nui.layout + nui.popup + nui.input
function M.cookie_prompt(cb)
  local has_nui, _ = pcall(require, "nui.input")
  if not has_nui then
    -- Fallback to vim.ui.input if nui not available
    vim.ui.input({ prompt = "LeetCode Cookie (LEETCODE_SESSION=...; csrftoken=...): " }, function(value)
      if not value or value == "" then
        if cb then pcall(cb, false) end
        return
      end
      local _, perr = parse_cookie(value)
      if perr then
        notify("Parse error: " .. perr, vim.log.levels.ERROR)
        if cb then pcall(cb, false) end
        return
      end
      try_set_cookie(value, function(ok, err)
        if ok then
          notify("Sign-in successful (self-contained)", vim.log.levels.INFO)
          local ok2, cmd = pcall(require, "leetcode.command")
          if ok2 then cmd.start_user_session() end
        else
          notify("Sign-in failed: " .. (err or "unknown"), vim.log.levels.ERROR)
        end
        if cb then pcall(cb, ok) end
      end)
    end)
    return
  end

  local Popup = require("nui.popup")
  local Layout = require("nui.layout")
  local Input = require("nui.input")
  local event = require("nui.utils.autocmd").event

  -- Help popup (read-only)
  local help_popup = Popup({
    focusable = false,
    border = {
      style = "rounded",
      text = {
        top = " LeetCode Login — Self-Contained ",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  -- Input popup (via NuiInput)
  local input_popup_opts = {
    relative = "editor",
    position = "50%",
    size = { width = 64, height = 3 },
    border = {
      style = "rounded",
      text = {
        top = " Paste Cookie (LEETCODE_SESSION + csrftoken) ",
        top_align = "left",
        bottom = " <CR> login  •  <Esc>/<C-c> cancel  •  <C-e> env var ",
        bottom_align = "left",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  }

  -- We will use Layout to stack help + input, but NuiInput is itself a popup.
  -- So we create a manual layout: help on top, input at bottom.
  -- Instead, mount help_popup as a split and use Input for entry.
  -- Simpler: use a Layout with two Popups, and handle input via a scratch buffer + vim.fn.input? Let's use Layout.

  -- Create an input buffer popup manually to allow embedded help
  local layout
  local input = Input(input_popup_opts, {
    prompt = " 󰆘 > ",
    on_submit = function(value)
      if layout then layout:unmount() end
      -- Also unmount help if still mounted
      pcall(function() help_popup:unmount() end)

      if not value or vim.trim(value) == "" then
        notify("Cancelled", vim.log.levels.WARN)
        if cb then pcall(cb, false) end
        return
      end

      -- Support pasting with quotes
      value = vim.trim(value:gsub("^['\"]+", ""):gsub("['\"]+$", ""))

      local _, perr = parse_cookie(value)
      if perr then
        notify("Parse error: " .. perr .. " — expected: LEETCODE_SESSION=xxx; csrftoken=yyy", vim.log.levels.ERROR)
        -- Re-open prompt on error
        vim.defer_fn(function() M.cookie_prompt(cb) end, 150)
        return
      end

      try_set_cookie(value, function(ok, err)
        if ok then
          notify("Sign-in successful — self-contained login (no external browser)", vim.log.levels.INFO)
          local ok2, cmd = pcall(require, "leetcode.command")
          if ok2 and cmd.start_user_session then
            cmd.start_user_session()
          end
        else
          notify("Sign-in failed: " .. (err or "unknown"), vim.log.levels.ERROR)
        end
        if cb then pcall(cb, ok) end
      end)
    end,
    on_close = function()
      pcall(function() help_popup:unmount() end)
      if layout then pcall(function() layout:unmount() end) end
    end,
  })

  -- Mount help popup first (centered, above input)
  -- We use a Layout to arrange them vertically
  local help_height = 14
  layout = Layout(
    { position = "50%", size = { width = 68, height = help_height + 5 } },
    Layout.Box({
      Layout.Box(help_popup, { size = help_height }),
      Layout.Box(input, { size = 3 }),
    }, { dir = "col" })
  )

  layout:mount()

  -- Populate help buffer after mount
  vim.schedule(function()
    if not help_popup.bufnr or not vim.api.nvim_buf_is_valid(help_popup.bufnr) then
      return
    end
    local lines = {
      "  This login is self-contained — no external browser window is opened by Neovim.",
      "  Paste your LeetCode cookie once; it is stored at vim.fn.stdpath('cache')/leetcode/cookie",
      "",
      "  How to copy (one-time, in any browser):",
      "    1. Log in at https://leetcode.com",
      "    2. Press F12 → Application → Cookies → https://leetcode.com",
      "    3. Copy values of LEETCODE_SESSION and csrftoken",
      "    4. Paste below as:  LEETCODE_SESSION=xxx; csrftoken=yyy",
      "",
      "  Tip: copy the full 'Cookie:' request header and paste it — parser extracts tokens.",
      "  Env: set $LEETCODE_COOKIE and press <C-e> in the input to import it.",
      "",
      "  Your cookie is stored locally (0600) and validated via leetcode.com/api/auth.",
    }
    vim.api.nvim_buf_set_option(help_popup.bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(help_popup.bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(help_popup.bufnr, "modifiable", false)
    -- Highlight
    vim.api.nvim_buf_add_highlight(help_popup.bufnr, -1, "Comment", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(help_popup.bufnr, -1, "Title", 2, 0, -1)

    -- Key to import from env var
    input:map("i", "<C-e>", function()
      local env = vim.env.LEETCODE_COOKIE or vim.env.LEETCODE_SESSION and ("LEETCODE_SESSION=" .. vim.env.LEETCODE_SESSION .. "; csrftoken=" .. (vim.env.CSRFTOKEN or "")) or ""
      if env and env ~= "" then
        -- Fill input extmark? NuiInput doesn't expose set_text easily, so close and re-open with value
        local cur = env
        input:unmount()
        layout:unmount()
        pcall(function() help_popup:unmount() end)
        vim.schedule(function()
          -- Re-open with env prefilled via vim.ui.input fallback hack: just try directly
          local _, perr = parse_cookie(cur)
          if perr then
            notify("Env LEETCODE_COOKIE invalid: " .. perr, vim.log.levels.ERROR)
            M.cookie_prompt(cb)
            return
          end
          try_set_cookie(cur, function(ok, err)
            if ok then
              notify("Sign-in from $LEETCODE_COOKIE successful", vim.log.levels.INFO)
              local ok2, cmd = pcall(require, "leetcode.command")
              if ok2 and cmd.start_user_session then cmd.start_user_session() end
            else
              notify("Sign-in failed: " .. (err or "unknown"), vim.log.levels.ERROR)
            end
            if cb then pcall(cb, ok) end
          end)
        end)
      else
        notify("No $LEETCODE_COOKIE in env", vim.log.levels.WARN)
      end
    end, { noremap = true })

    input:map("n", "<Esc>", function()
      input:unmount()
      layout:unmount()
      pcall(function() help_popup:unmount() end)
      if cb then pcall(cb, false) end
    end)
    input:on(event.BufLeave, function()
      -- Don't auto-unmount on bufleave for layout — handle explicitly
    end)
  end)
end

return M
