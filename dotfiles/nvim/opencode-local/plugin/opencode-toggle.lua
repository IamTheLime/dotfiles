local api = vim.api

-- This table will hold the state of our terminal
local term = {
    buf = nil,
    win = nil,
    job_id = nil,
}


-- Opens the terminal window in a floating window
local function open_term_win()
    local width = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines * 0.8)
    local row = math.ceil((vim.o.lines - height) / 2)
    local col = math.ceil((vim.o.columns - width) / 2)

    term.win = api.nvim_open_win(term.buf, true, {
        relative = "editor",
        style = "minimal",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        
    })
    vim.cmd("startinsert")
end

-- Closes the terminal window
local function close_term_win()
    if term.win and api.nvim_win_is_valid(term.win) then
        api.nvim_win_close(term.win, true)
        term.win = nil
    end
end

-- The main toggle function
local function toggle()
    -- If the window is already open, close it.
    if term.win and api.nvim_win_is_valid(term.win) then
        close_term_win()
        return
    end

    -- If the buffer exists but the window is closed, just reopen the window
    -- to show the existing terminal session.
    if term.buf and api.nvim_buf_is_valid(term.buf) then
        open_term_win()
        return
    end

    -- If we're here, no terminal exists yet. Let's create one.
    term.buf = api.nvim_create_buf(false, true)
    vim.bo[term.buf].bufhidden = 'hide'

    -- Use an autocommand to clean up our state when the terminal closes.
    local group = api.nvim_create_augroup("OpencodeTermCleanup", { clear = true })
    api.nvim_create_autocmd("TermClose", {
        group = group,
        buffer = term.buf,
        callback = vim.schedule_wrap(function()
            -- The buffer will be deleted by Neovim. We just need to reset our state.
            term.buf = nil
            term.win = nil
            term.job_id = nil
        end),
    })

    -- Now, open the window to display the terminal
    open_term_win()

    local term = vim.api.nvim_open_term(term.buf, {
        on_input = function(_, _, _, data)
            vim.api.nvim_chan_send(job, data)
        end,
        force_crlf = false,
    })

    job = vim.fn.jobstart({ 'opencode' }, {
        pty = true,
        on_stdout = function(_, data, _)
            vim.api.nvim_chan_send(term, table.concat(data, '\n'))
        end,
    })
end

api.nvim_create_user_command("OpencodeToggle", toggle, {})
