local keymap = vim.keymap

keymap.set('n', 'x', '"_x')

-- Increment/decrement
keymap.set('n', '+', '<C-a>')
keymap.set('n', '-', '<C-x>')

-- Select all
keymap.set('n', '<C-a>', 'gg<S-v>G')

-- Save with root permission (not working for now)
--vim.api.nvim_create_user_command('W', 'w !sudo tee > /dev/null %', {})

-- New tab
keymap.set('n', 'te', ':tabedit')

keymap.set('t', '<C-Space>', "<C-\\><C-n>", { silent = true })

keymap.set('n', '<C-n>n', function()
    local status, error = pcall(vim.cmd, "cnext")
    if error then
        print("Hey dummy perhaps you want to try to create a quickfix list before")
    end
end)
keymap.set('n', '<C-n>p', function()
    local status, error = pcall(vim.cmd, "cprev")
    if error then
        print("Hey dummy perhaps you want to try to create a quickfix list before")
    end
end)
