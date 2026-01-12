-- Layout system for floating windows
-- Adapted from fff.nvim (https://github.com/dmtrKovalenko/fff.nvim)
-- MIT License - Dmytro Kovalenko
--

local combo_renderer = require('journal-local.plugin.combo_renderer')
local utils = require('journal-local.plugin.utils')
local conf = require('journal-local.plugin.layout_conf')


local LAYOUT_CONF = {
    height = 0.8,
    width = 0.8,
    prompt_position = 'bottom', -- or 'top'
    preview_position = 'right', -- or 'left', 'right', 'top', 'bottom'
    preview_size = 0.5,
    show_scrollbar = true,      -- Show scrollbar for pagination
}

local M = {}

M.state = {
    active = false,
    layout = nil,
    input_win = nil,
    input_buf = nil,
    list_win = nil,
    list_buf = nil,
    file_info_win = nil,
    file_info_buf = nil,
    preview_win = nil,
    preview_buf = nil,

    items = {},
    filtered_items = {},
    cursor = 1,
    top = 1,
    query = '',
    item_line_map = {},
    location = nil, -- Current location from search results

    -- History cycling state
    history_offset = nil,                  -- Current offset in history (nil = not cycling, 0 = first query)
    next_search_force_combo_boost = false, -- Force combo boost on next search (for history recall)

    -- Combo state
    combo_visible = true,       -- Whether to show combo indicator (hidden after significant navigation)
    combo_initial_cursor = nil, -- Initial cursor position when combo was shown

    -- Pagination state
    pagination = {
        page_index = 0,      -- Current page index (0-based)
        page_size = 20,      -- Items per page (updated dynamically)
        total_matched = 0,   -- Total results from last search
        prefetch_margin = 5, -- Trigger refetch when within N items of edge
    },

    config = nil,

    ns_id = nil,

    last_status_info = nil,

    last_preview_file = nil,
    last_preview_location = nil, -- Track last preview location to detect changes

    preview_timer = nil,         -- Separate timer for preview updates
    preview_debounce_ms = 100,   -- Preview is more expensive, debounce more

    -- Set of selected file paths: { [filepath] = true }
    -- Uses Set pattern: selected items exist as keys with value true, deselected items are removed (nil)
    -- This allows O(1) lookup and automatic deduplication without needing to filter false values
    selected_files = {},
}


function M.enabled_preview()
    return true
end

--- Calculate layout dimensions and positions for all windows
--- @param cfg LayoutConfig
--- @return table Layout configuration
function M.calculate_layout_dimensions(cfg)
    local BORDER_SIZE = 2
    local PROMPT_HEIGHT = 2
    local SEPARATOR_WIDTH = 1
    local SEPARATOR_HEIGHT = 1

    if not utils.is_one_of(cfg.preview_position, { 'left', 'right', 'top', 'bottom' }) then
        error('Invalid preview position: ' .. tostring(cfg.preview_position))
    end

    local layout = {}

    preview_enabled = M.enabled_preview()

    -- Section 1: Base dimensions and bounds checking
    local total_width = math.max(0, cfg.total_width - BORDER_SIZE)
    local total_height = math.max(0, cfg.total_height - BORDER_SIZE - PROMPT_HEIGHT)

    -- Section 2: Calculate dimensions based on preview position
    if cfg.preview_position == 'left' then
        local separator_width = preview_enabled and SEPARATOR_WIDTH or 0
        local list_width = math.max(0, total_width - cfg.preview_width - separator_width)
        local list_height = total_height

        layout.list_col = cfg.start_col + cfg.preview_width + 3 -- +3 for borders and separator
        layout.list_width = list_width
        layout.list_height = list_height
        layout.input_col = layout.list_col
        layout.input_width = list_width

        if preview_enabled then
            layout.preview = {
                col = cfg.start_col + 1,
                row = cfg.start_row + 1,
                width = cfg.preview_width,
                height = list_height,
            }
        end
    elseif cfg.preview_position == 'right' then
        local separator_width = preview_enabled and SEPARATOR_WIDTH or 0
        local list_width = math.max(0, total_width - cfg.preview_width - separator_width)
        local list_height = total_height

        layout.list_col = cfg.start_col + 1
        layout.list_width = list_width
        layout.list_height = list_height
        layout.input_col = layout.list_col
        layout.input_width = list_width

        if preview_enabled then
            layout.preview = {
                col = cfg.start_col + list_width + 3, -- +3 for borders and separator (matches original)
                row = cfg.start_row + 1,
                width = cfg.preview_width,
                height = list_height,
            }
        end
    elseif cfg.preview_position == 'top' then
        local separator_height = preview_enabled and SEPARATOR_HEIGHT or 0
        local list_height = math.max(0, total_height - cfg.preview_height - separator_height)

        layout.list_col = cfg.start_col + 1
        layout.list_width = total_width
        layout.list_height = list_height
        layout.input_col = layout.list_col
        layout.input_width = total_width
        layout.list_start_row = cfg.start_row + (preview_enabled and (cfg.preview_height + separator_height) or 0) + 1

        if preview_enabled then
            layout.preview = {
                col = cfg.start_col + 1,
                row = cfg.start_row + 1,
                width = total_width,
                height = cfg.preview_height,
            }
        end
    else
        local separator_height = preview_enabled and SEPARATOR_HEIGHT or 0
        local list_height = math.max(0, total_height - cfg.preview_height - separator_height)

        layout.list_col = cfg.start_col + 1
        layout.list_width = total_width
        layout.list_height = list_height
        layout.input_col = layout.list_col
        layout.input_width = total_width
        layout.list_start_row = cfg.start_row + 1

        if preview_enabled then
            layout.preview = {
                col = cfg.start_col + 1,
                width = total_width,
                height = cfg.preview_height,
            }
        end
    end

    -- Section 3: Position prompt and adjust row positions
    if cfg.preview_position == 'left' or cfg.preview_position == 'right' then
        if cfg.prompt_position == 'top' then
            layout.input_row = cfg.start_row + 1
            layout.list_row = cfg.start_row + PROMPT_HEIGHT + 1
        else
            layout.list_row = cfg.start_row + 1
            layout.input_row = cfg.start_row + cfg.total_height - BORDER_SIZE
        end

        if layout.preview then
            if cfg.prompt_position == 'top' then
                layout.preview.row = cfg.start_row + 1
                layout.preview.height = cfg.total_height - BORDER_SIZE
            else
                layout.preview.row = cfg.start_row + 1
                layout.preview.height = cfg.total_height - BORDER_SIZE
            end
        end
    else
        local list_start_row = layout.list_start_row
        if cfg.prompt_position == 'top' then
            layout.input_row = list_start_row
            layout.list_row = list_start_row + BORDER_SIZE
            layout.list_height = math.max(0, layout.list_height - BORDER_SIZE)
        else
            layout.list_row = list_start_row
            layout.input_row = list_start_row + layout.list_height + 1
        end

        if cfg.preview_position == 'bottom' and layout.preview then
            if cfg.prompt_position == 'top' then
                layout.preview.row = layout.list_row + layout.list_height + 1
            else
                layout.preview.row = layout.input_row + PROMPT_HEIGHT
            end
        end
    end

    -- Section 4: Position debug panel (if enabled)
    if cfg.debug_enabled and preview_enabled and layout.preview then
        if cfg.preview_position == 'left' or cfg.preview_position == 'right' then
            layout.file_info = {
                width = layout.preview.width,
                height = cfg.file_info_height,
                col = layout.preview.col,
                row = layout.preview.row,
            }
            layout.preview.row = layout.preview.row + cfg.file_info_height + SEPARATOR_HEIGHT + 1
            layout.preview.height = math.max(3, layout.preview.height - cfg.file_info_height - SEPARATOR_HEIGHT - 1)
        else
            layout.file_info = {
                width = layout.preview.width,
                height = cfg.file_info_height,
                col = layout.preview.col,
                row = layout.preview.row,
            }
            layout.preview.row = layout.preview.row + cfg.file_info_height + SEPARATOR_HEIGHT + 1
            layout.preview.height = math.max(3, layout.preview.height - cfg.file_info_height - SEPARATOR_HEIGHT - 1)
        end
    end

    return layout
end

local function get_prompt_position()
    local config = M.state.config

    if config and config.layout and config.layout.prompt_position then
        local terminal_width = vim.o.columns
        local terminal_height = vim.o.lines

        return utils.resolve_config_value(
            config.layout.prompt_position,
            terminal_width,
            terminal_height,
            function(value) return utils.is_one_of(value, { 'top', 'bottom' }) end,
            'bottom',
            'layout.prompt_position'
        )
    end

    return 'bottom'
end

local function get_preview_position()
    local config = M.state.config

    if config and config.layout and config.layout.preview_position then
        local terminal_width = vim.o.columns
        local terminal_height = vim.o.lines

        return utils.resolve_config_value(
            config.layout.preview_position,
            terminal_width,
            terminal_height,
            function(value) return utils.is_one_of(value, { 'left', 'right', 'top', 'bottom' }) end,
            'right',
            'layout.preview_position'
        )
    end

    return 'right'
end

-- UI functions

function M.create_ui()
    local config = M.state.config

    if not M.state.ns_id then
        M.state.ns_id = vim.api.nvim_create_namespace('fff_picker_status')
        combo_renderer.init(M.state.ns_id)
    end

    local debug_enabled_in_preview = M.enabled_preview() and config and config.debug and config.debug.show_scores

    local terminal_width = vim.o.columns
    local terminal_height = vim.o.lines

    -- Calculate width and height (support function or number)
    local width_ratio = utils.resolve_config_value(
        config.layout.width,
        terminal_width,
        terminal_height,
        utils.is_valid_ratio,
        0.8,
        'layout.width'
    )
    local height_ratio = utils.resolve_config_value(
        config.layout.height,
        terminal_width,
        terminal_height,
        utils.is_valid_ratio,
        0.8,
        'layout.height'
    )

    local width = math.floor(terminal_width * width_ratio)
    local height = math.floor(terminal_height * height_ratio)

    -- Calculate col and row (support function or number)
    local col_ratio_default = 0.5 - (width_ratio / 2) -- default center
    local col_ratio
    if config.layout.col ~= nil then
        col_ratio = utils.resolve_config_value(
            config.layout.col,
            terminal_width,
            terminal_height,
            utils.is_valid_ratio,
            col_ratio_default,
            'layout.col'
        )
    else
        col_ratio = col_ratio_default
    end
    local row_ratio_default = 0.5 - (height_ratio / 2) -- default center
    local row_ratio
    if config.layout.row ~= nil then
        row_ratio = utils.resolve_config_value(
            config.layout.row,
            terminal_width,
            terminal_height,
            utils.is_valid_ratio,
            row_ratio_default,
            'layout.row'
        )
    else
        row_ratio = row_ratio_default
    end

    local col = math.floor(terminal_width * col_ratio)
    local row = math.floor(terminal_height * row_ratio)

    local prompt_position = get_prompt_position()
    local preview_position = get_preview_position()

    local preview_size_ratio = utils.resolve_config_value(
        config.layout.preview_size,
        terminal_width,
        terminal_height,
        utils.is_valid_ratio,
        0.4,
        'layout.preview_size'
    )

    local layout_config = {
        total_width = width,
        total_height = height,
        start_col = col,
        start_row = row,
        preview_position = preview_position,
        prompt_position = prompt_position,
        debug_enabled = debug_enabled_in_preview,
        preview_width = M.enabled_preview() and math.floor(width * preview_size_ratio) or 0,
        preview_height = M.enabled_preview() and math.floor(height * preview_size_ratio) or 0,
        separator_width = 3,
        file_info_height = debug_enabled_in_preview and 10 or 0,
    }

    local layout = M.calculate_layout_dimensions(layout_config)
    M.state.layout = layout

    M.state.input_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.state.input_buf, 'bufhidden', 'wipe')

    M.state.list_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.state.list_buf, 'bufhidden', 'wipe')

    if M.enabled_preview() then
        M.state.preview_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(M.state.preview_buf, 'bufhidden', 'wipe')
    end

    if debug_enabled_in_preview then
        M.state.file_info_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(M.state.file_info_buf, 'bufhidden', 'wipe')
    else
        M.state.file_info_buf = nil
    end

    -- Create list window with conditional title based on prompt position
    local list_window_config = {
        relative = 'editor',
        width = layout.list_width,
        height = layout.list_height,
        col = layout.list_col,
        row = layout.list_row,
        -- To make the input feel connected with the picker, we customize the
        -- respective corner border characters based on prompt_position
        border = prompt_position == 'bottom' and { '┌', '─', '┐', '│', '', '', '', '│' }
            or { '├', '─', '┤', '│', '┘', '─', '└', '│' },
        style = 'minimal',
    }

    local title = ' ' .. (M.state.config.title or 'FFFiles') .. ' '
    -- Only add title if prompt is at bottom - when prompt is top, title should be on input
    if prompt_position == 'bottom' then
        list_window_config.title = title
        list_window_config.title_pos = 'left'
    end

    M.state.list_win = vim.api.nvim_open_win(M.state.list_buf, false, list_window_config)

    -- Create file info window if debug enabled
    if debug_enabled_in_preview and layout.file_info then
        M.state.file_info_win = vim.api.nvim_open_win(M.state.file_info_buf, false, {
            relative = 'editor',
            width = layout.file_info.width,
            height = layout.file_info.height,
            col = layout.file_info.col,
            row = layout.file_info.row,
            border = 'single',
            style = 'minimal',
            title = ' File Info ',
            title_pos = 'left',
        })
    else
        M.state.file_info_win = nil
    end

    -- Create preview window
    if M.enabled_preview() and layout.preview then
        M.state.preview_win = vim.api.nvim_open_win(M.state.preview_buf, false, {
            relative = 'editor',
            width = layout.preview.width,
            height = layout.preview.height,
            col = layout.preview.col,
            row = layout.preview.row,
            border = 'single',
            style = 'minimal',
            title = ' Preview ',
            title_pos = 'left',
        })
    end

    -- Create input window with conditional title based on prompt position
    local input_window_config = {
        relative = 'editor',
        width = layout.input_width,
        height = 1,
        col = layout.input_col,
        row = layout.input_row,
        -- To make the input feel connected with the picker, we customize the
        -- respective corner border characters based on prompt_position
        border = prompt_position == 'bottom' and { '├', '─', '┤', '│', '┘', '─', '└', '│' }
            or { '┌', '─', '┐', '│', '', '', '', '│' },
        style = 'minimal',
    }

    -- Add title if prompt is at top - title appears above the prompt
    if prompt_position == 'top' then
        input_window_config.title = title
        input_window_config.title_pos = 'left'
    end

    M.state.input_win = vim.api.nvim_open_win(M.state.input_buf, false, input_window_config)

    M.setup_buffers()
    M.setup_windows()
    M.setup_keymaps()

    vim.api.nvim_set_current_win(M.state.input_win)

    -- preview.set_preview_window(M.state.preview_win)

    M.update_results_sync()
    M.clear_preview()
    M.update_status()

    return true
end

function M.open()
    M.state.config = conf.get()
    if M.state.active then return end

    -- Initialize selection state
    M.state.selected_files = {}

    if not M.create_ui() then
        vim.notify('Failed to create picker UI', vim.log.levels.ERROR)
        return false
    end
end

return M
