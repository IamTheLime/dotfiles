local api = vim.api
local M = {}

local function swap_with_picked_window()
    local source = api.nvim_get_current_win()
    if api.nvim_win_get_config(source).relative ~= "" then return end

    local count = 0
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        if api.nvim_win_get_config(win).relative == "" then count = count + 1 end
    end
    if count < 2 then return end
    if count > 26 then
        vim.notify("Window swap supports up to 26 splits per tab", vim.log.levels.WARN)
        return
    end

    require("nvim-window").pick()
    local target = api.nvim_get_current_win()
    if target == source or not api.nvim_win_is_valid(source) then return end

    -- Keep the source slot in the layout while moving windows between nested splits.
    local sizes = vim.fn.winrestcmd()
    local slot = api.nvim_open_win(api.nvim_win_get_buf(source), false, {
        split = "left", win = source, width = 1, noautocmd = true,
    })
    local moved_source = false
    local ok, err = pcall(function()
        api.nvim_win_set_config(source, { split = "left", win = target })
        moved_source = true
        api.nvim_win_set_config(target, { split = "left", win = slot })
    end)
    if not ok and moved_source then
        api.nvim_win_set_config(source, { split = "right", win = slot })
    end
    api.nvim_win_close(slot, true)
    api.nvim_set_current_win(source)
    vim.cmd(sizes)
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
end

function M.setup()
    local map = vim.keymap.set
    map("n", "sh", ":split<Return><C-w>w")
    map("n", "sv", ":vsplit<Return><C-w>w")
    map("n", "<Space>", "<C-w>w")
    map("n", "<C-w><Left>", "<C-w><")
    map("n", "<C-w><Right>", "<C-w>>")
    map("n", "<C-w><Up>", "<C-w>+")
    map("n", "<C-w><Down>", "<C-w>-")
    map("n", "<Leader>ws", swap_with_picked_window, { desc = "Swap with a labelled split" })
end

return M
