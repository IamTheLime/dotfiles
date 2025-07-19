local api = vim.api

local M = {}

-- This table will hold the state of our terminal instance
M.term_instance = nil

function M.recalculate_layout()
    local total_height = math.ceil(vim.o.lines * 0.8)
    local total_width = math.ceil(vim.o.columns * 0.8)
    return {
        width = total_width - 2,   -- account for 1 char border on each side
        height = total_height - 2, -- account for 1 char border on each side
        row = math.ceil((vim.o.lines - total_height) / 2),
        col = math.ceil((vim.o.columns - total_width) / 2),
    }
end

function M.open_or_update_window()
    local term = M.term_instance
    if not term then return end

    local layout = M.recalculate_layout()

    if term.win and api.nvim_win_is_valid(term.win) then
        api.nvim_win_set_config(term.win, {
            style = 'minimal',
            relative = 'editor',
            row = layout.row,
            col = layout.col,
            width = layout.width,
            height = layout.height,
            border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
        })
    else
        local normal_bg = api.nvim_get_hl(0, { name = "Normal" }).bg
        api.nvim_set_hl(0, "OpencodeFloat", { bg = normal_bg })

        term.win = api.nvim_open_win(term.buf, true, {
            style = 'minimal',
            relative = 'editor',
            row = layout.row,
            col = layout.col,
            width = layout.width,
            height = layout.height,
            border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
        })
    end

    api.nvim_set_current_win(term.win)
    vim.cmd("startinsert")
end

function M.create_terminal()
    M.term_instance = {}
    local term = M.term_instance

    term.buf = api.nvim_create_buf(false, true)

    term.job_id = vim.api.nvim_call_function("termopen", {
        "opencode",
        {
            on_exit = function()
                if term.win and api.nvim_win_is_valid(term.win) then
                    api.nvim_win_close(term.win, true)
                end
                M.term_instance = nil
            end,
        }
    })

    vim.bo[term.buf].bufhidden = 'hide'

    local group = api.nvim_create_augroup("OpencodeToggleCleanup", { clear = true })
    api.nvim_create_autocmd("TermClose", {
        group = group,
        buffer = term.buf,
        callback = function()
            if M.term_instance and M.term_instance.win and api.nvim_win_is_valid(M.term_instance.win) then
                api.nvim_win_close(M.term_instance.win, true)
            end
            M.term_instance = nil
        end,
    })
end

function M.is_visible()
    if not M.term_instance or not M.term_instance.win or not api.nvim_win_is_valid(M.term_instance.win) then
        return false
    end

    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        if win == M.term_instance.win then
            return true
        end
    end

    return false
end

function M.toggle()
    if M.is_visible() then
        api.nvim_win_hide(M.term_instance.win)
    else
        if not M.term_instance then
            M.create_terminal()
        end
        M.open_or_update_window()
    end
end

api.nvim_create_user_command("OpencodeToggle", M.toggle, {})

return M
