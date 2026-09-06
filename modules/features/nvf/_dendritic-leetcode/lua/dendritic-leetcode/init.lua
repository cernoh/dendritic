-- dendritic-leetcode/init.lua
-- Main entry for the dendritic self-contained LeetCode plugin.
-- Overrides leetcode.nvim's cookie_prompt with our self-contained UI and
-- provides :DendriticLeetLogin command.
-- Follows nvf lazy-loading advice: setup() is called from vim.lazy.plugins.after.

local M = {}

local function patch_leetcode()
  local ok, cmd = pcall(require, "leetcode.command")
  if ok and cmd then
    local login = require("dendritic-leetcode.login")
    -- Preserve original for fallback
    if not cmd._dendritic_orig_cookie_prompt then
      cmd._dendritic_orig_cookie_prompt = cmd.cookie_prompt
    end
    cmd.cookie_prompt = login.cookie_prompt
  end
end

function M.setup(opts)
  opts = opts or {}

  -- Try immediate patch (if leetcode already loaded), else defer via autocmd
  local patched = false
  if pcall(require, "leetcode.command") then
    patch_leetcode()
    patched = true
  end

  if not patched then
    -- leetcode.nvim lazy-loads on :Leet; patch when its module loads
    -- Use User autocmd that leetcode fires on enter, plus lazy load hook
    vim.api.nvim_create_autocmd({ "User" }, {
      pattern = { "LeetCodeStart", "LeetCodeEnter" },
      once = false,
      callback = function() pcall(patch_leetcode) end,
    })
    -- Also try on CmdUndefined for Leet
    vim.api.nvim_create_autocmd("CmdUndefined", {
      pattern = "Leet",
      once = true,
      callback = function() vim.defer_fn(function() pcall(patch_leetcode) end, 200) end,
    })
  end

  -- Provide user command that is always available (self-contained)
  vim.api.nvim_create_user_command("DendriticLeetLogin", function()
    require("dendritic-leetcode.login").cookie_prompt(function(ok)
      if ok then
        vim.notify("[dendritic-leetcode] Login complete — try :Leet", vim.log.levels.INFO)
      end
    end)
  end, { desc = "LeetCode login (browser auto-capture, cookie-paste fallback)" })

  -- Also alias to :LeetLogin for ergonomics
  pcall(vim.api.nvim_create_user_command, "LeetLogin", function()
    vim.cmd("DendriticLeetLogin")
  end, { desc = "Alias for DendriticLeetLogin" })

  -- Cancel an in-progress browser login poll
  pcall(vim.api.nvim_create_user_command, "DendriticLeetCancel", function()
    require("dendritic-leetcode.browser").cancel()
  end, { desc = "Cancel in-progress browser login" })

  -- Keymap hint (not bound by default to avoid conflict; user can map)
  if opts.auto_patch_signin ~= false then
    -- Monkey-patch the signin page to show our branding when it renders
    vim.defer_fn(function()
      local ok2, page = pcall(require, "leetcode-ui.group.page.signin")
      if ok2 and page and type(page) == "table" then
        -- page is a Page object; we can't easily re-render, but we ensure our
        -- login button text will be overridden next time menu rebuilds
        -- So we patch the module's return for future requires
        package.loaded["leetcode-ui.group.page.signin"] = nil
      end
    end, 0)
  end
end

return M
