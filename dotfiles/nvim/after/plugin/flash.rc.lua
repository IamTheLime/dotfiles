-- This will be the place to setup and initialise all mini related stuff
local status, flash = pcall(require, "flash")
if (not status) then return end

flash.setup()

vim.keymap.set('n', 's;', function()
    require("flash").treesitter()
end)
vim.keymap.set('o', 's;', function()
    require("flash").treesitter()
end)
vim.keymap.set('x', 's;', function()
    require("flash").treesitter()
end)
vim.keymap.set('n', 'ss', function()
    require("flash").jump()
end)
vim.keymap.set('o', 'ss', function()
    require("flash").jump()
end)
vim.keymap.set('x', 'ss', function()
    require("flash").jump()
end)
