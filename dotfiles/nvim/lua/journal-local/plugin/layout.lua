local function open_term_win()
    local width = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines * 0.8)
    local row = math.ceil((vim.o.lines - height) / 2)
    local col = math.ceil((vim.o.columns - width) / 2)

    return vim.api.nvim_open_win(0, true, {
        relative = "editor",
        style = "minimal",
        width = width,
        height = height,
        row = row,
        col = col,
    })
end


local M = {}
--- @class OpenTitleOpts
--- @field code_preview_ft? string The filetype for the preview buffer

--- @class LayoutConfig
--- @field title_w number The window ID for the title
--- @field title_buf number The buffer ID for the title
--- @field description_w number The window ID for the description
--- @field description_buf number The buffer ID for the description
--- @field preview_w number The window ID for the preview
--- @field preview_buf number The buffer ID for the preview

--- Opens a window layout with title, description, and preview buffers
--- @param opts? OpenTitleOpts Options for the window layout
--- @return LayoutConfig The configuration with handles to the created windows and buffers
function M.open_title_window(opts)
    opts = opts or {}

    local title_buf = vim.api.nvim_create_buf(false, true)
    local description_buf = vim.api.nvim_create_buf(false, true)
    local preview_buf = vim.api.nvim_create_buf(false, true)

    local width = math.ceil(vim.o.columns * 0.8)
    local height = math.ceil(vim.o.lines * 0.8)
    local row = math.ceil((vim.o.lines - height) / 2)
    local col = math.ceil((vim.o.columns - width) / 2)

    -- Title window: top 1 line
    local title_window = vim.api.nvim_open_win(title_buf, true, {
        relative = "editor",
        style = "minimal",
        border = "single",
        width = width,
        height = 1,
        row = row,
        col = col,
    })

    -- Description window: below title, left side
    local description_window = vim.api.nvim_open_win(description_buf, false, {
        relative = "editor",
        style = "minimal",
        border = "single",
        width = math.floor(width * 0.5),
        height = height - 1,
        row = row + 1,
        col = col,
    })

    -- Preview window: right side, full height minus title
    local preview_window = vim.api.nvim_open_win(preview_buf, false, {
        relative = "editor",
        style = "minimal",
        border = "single",
        width = width - math.floor(width * 0.5),
        height = height - 3,
        row = row + 3,
        col = col + math.floor(width * 0.5),
    })

    local layout_conf = {
        title_w = title_window,
        title_buf = title_buf,
        description_w = description_window,
        description_buf = description_buf,
        preview_w = preview_window,
        preview_buf = preview_buf,
    }

    -- Set up autocmd to close all windows when any one is closed
    local group = vim.api.nvim_create_augroup("LayoutClose", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(args)
            local closed_win = tonumber(args.match)
            if closed_win == title_window or closed_win == description_window or closed_win == preview_window then
                for _, w in ipairs({title_window, description_window, preview_window}) do
                    if w ~= closed_win and vim.api.nvim_win_is_valid(w) then
                        vim.api.nvim_win_close(w, true)
                    end
                end
            end
        end
    })

    -- vim.api.nvim_buf_set_option_value('filetype', 'markdown', {buf =layout_conf.description_buf})
    -- vim.api.nvim_buf_set_option_value('filetype', opts.code_preview_ft or "txt", { buf = layout_conf.preview_buf })

    return layout_conf
end

--- Closes all windows in the layout configuration
--- @param config LayoutConfig The configuration returned by open_title_window
function M.close_title_window(config)
    if config.title_w and vim.api.nvim_win_is_valid(config.title_w) then
        vim.api.nvim_win_close(config.title_w, true)
    end
    if config.description_w and vim.api.nvim_win_is_valid(config.description_w) then
        vim.api.nvim_win_close(config.description_w, true)
    end
    if config.preview_w and vim.api.nvim_win_is_valid(config.preview_w) then
        vim.api.nvim_win_close(config.preview_w, true)
    end
end

return M
