vim.g.mapleader = "\\"
require('lima_the_lime.base')
require('lima_the_lime.highlights')
require('lima_the_lime.maps')
require('lima_the_lime.macos')

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)


local lazy = require("lazy")

-- This line will inject anything in
-- ~/.config/nvim/lua/plugins.lua or ~/.config/nvim/lua/plugins/init.lua (this file is optional)
-- but also load all the plugins in
-- ~/.config/nvim/lua/plugins/*.lua
lazy.setup("plugins", {
    change_detection = {
        enabled = true,
        notify = false,
    }
})

vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup('custom-term-open', { clear = true }),
    callback = function()
        vim.opt.number = false
        vim.opt.relativenumber = false
    end,
})

-- Profiling command 
--
--
--
-- 1. Define the state variable and log file path
vim.g.profiling_active = 0
local profile_log_file = vim.fn.expand('/tmp/profile.log')

-- 2. Create the function
local function profile_toggle()
  if vim.g.profiling_active == 0 then
    -- --- START PROFILING ---
    print("Profiling started. Log: " .. profile_log_file)
    vim.cmd('profile start ' .. profile_log_file)
    vim.cmd('profile func *')
    vim.cmd('profile file *')
    vim.g.profiling_active = 1
  else
    -- --- STOP PROFILING ---
    print("Profiling paused. Quitting Neovim to write the log...")
    vim.cmd('profile pause')
    -- Quits Neovim and writes the log
    vim.cmd('noautocmd qall!')
    vim.g.profiling_active = 0
  end
end

-- 3. Map the function to the desired keybind: <Leader>sp
vim.keymap.set('n', '<Leader>sp', profile_toggle, { desc = 'Toggle Neovim Profiling', silent = true })
