require("vim_config")
require("plugin")

-- Machine-local overrides: ~/.config/nvim-local/lua/local.lua, never managed by
-- Home Manager. Runs after lazy.setup, so it can set options and keymaps but
-- cannot add plugins.
local local_dir = vim.fn.stdpath("config") .. "-local"
if vim.fn.isdirectory(local_dir) == 1 then
  vim.opt.rtp:prepend(local_dir)
  local ok, err = pcall(require, "local")
  if not ok then
    -- nvim_echo with err=true reaches stderr headless and the message area
    -- interactively; plugins may replace vim.notify and hide it.
    vim.api.nvim_echo({ { "nvim-local: " .. tostring(err), "WarningMsg" } }, true, { err = true })
  end
end
