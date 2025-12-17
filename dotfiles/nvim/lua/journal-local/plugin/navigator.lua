local layout = require('journal-local.plugin.layout')

local navigator = {}
local log = require('plenary.log')
local logger = log.new({ plugin = 'navigator', level = 'info', })
---------------------------------------------------
---------------------------------------------------
-- Definition of state for the plugin
---------------------------------------------------
---------------------------------------------------

local CodeRange = {}
---@class CodeRange
---@field line_start_row integer
---@field line_start_col integer
---@field line_end_row integer
---@field line_end_col integer


---Holds the Value for
---@return CodeRange
function CodeRange:new()
    local vim_mode = vim.api.nvim_get_mode().mode

    local start = nil
    local final = nil
    if (vim.fn.getpos("v")[2] > vim.fn.getpos(".")[2]) then
        start = "."
        final = "v"
    else
        start = "v"
        final = "."
    end

    local line_start_row = vim.fn.getpos(start)[2]
    local line_start_col = nil
    if vim_mode == "V" then
        line_start_col = 0
    else
        line_start_col = vim.fn.getpos(start)[3]
    end


    local line_end_row = vim.fn.getpos(final)[2]
    local line_end_col = nil
    if vim_mode == "V" then
        local line = vim.fn.getline(line_end_row)
        line_end_col = vim.fn.strdisplaywidth(line)
    else
        line_end_col = vim.fn.getpos(final)[3]
    end

    local obj = {
        line_start_row = line_start_row,
        line_start_col = line_start_col,
        line_end_row = line_end_row,
        line_end_col = line_end_col,
    }
    setmetatable(obj, self)
    return obj
end

local JournalEntry = {}
---@class JournalEntry
---@field title string
---@field code_location CodeRange
---@field date string

---@param id integer
---@return JournalEntry
function JournalEntry:create_new_entry_from_selection(id)
    local date = vim.fn.strftime("%Y %b %d %X")
    local code_range = CodeRange:new()
    local title = "Failed to receive input"
    vim.ui.input({ prompt = 'Set title: ' }, function(input)
        title = input
    end)

    local obj = {
        title = title,
        relevant_areas = code_range,
        date = date,
        id = id
    }

    setmetatable(obj, self)
    return obj
end

---@class Journal
---@field entries JournalEntry[]
---@field current_entry integer
local Journal = {}

---@return Journal
function Journal:new()
    local obj = { entries = {}, current_entry = -1, }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function Journal:create_and_add_new_entry()
    self.current_entry = self.current_entry + 1
    local je = JournalEntry:create_new_entry_from_selection(self.current_entry)
    table.insert(self.entries, je)
end

---@param path string
function Journal:load_journal(path)
    error("Method not implemented")
end

---@param entry JournalEntry
function Journal:add_entry(entry)
    table.insert(self.entries, entry)
end

function Journal:explore()
    vim.cmd("echo 42")
    print("Not yet implemented")
end

---------------------------------------------------
---------------------------------------------------
-- Misc setup
-------------------------------------------------
---------------------------------------------------
---@type Journal[]
Book = {}

navigator.setup = function(opts)
    opts = opts or {}
    -- Initialize state, commands, keymaps here
    -- vim.api.nvim_create_user_command('NavigatorExplore', navigator.explore, {})
end

navigator.test = function()
    -- local j = Journal:new()
    -- j:create_and_add_new_entry()
    -- logger.info(j)
    layout.open_title_window({code_preview_ft="py"})
end

navigator.setup({})

vim.keymap.set('v', 'mmm', navigator.test, {})

-- Hot reload setup (development)
if vim.fn.has('nvim-0.7') == 1 then
    local ok, dev_utils = pcall(require, 'dev-utils')
    if ok then
        dev_utils.register_plugin('journal-navigator', {
            pattern = '^journal%-local%.plugin',
            entry_point = 'journal-local.plugin.navigator',
            reset_globals = function()
                -- Reset global state
                Book = {}
            end
        })
        
        -- Create a command for quick reloading during development
        vim.api.nvim_create_user_command('JournalReload', function()
            dev_utils.reload_plugin('journal-navigator')
        end, { desc = 'Hot reload journal navigator plugin' })
    end
end

return navigator
