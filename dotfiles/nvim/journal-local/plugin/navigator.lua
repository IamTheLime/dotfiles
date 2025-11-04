local navigator = {}

---------------------------------------------------
---------------------------------------------------
-- Definition of state for the plugin
---------------------------------------------------
---------------------------------------------------

---@class CodeRange
---@field line_start_row integer
---@field line_start_col integer
---@field line_end_row integer
---@field line_end_col integer
local CodeRange = {}


---Holds the Value for
---@return CodeRange
function CodeRange:new()

    local vim_mode = vim.api.nvim_get_mode()

    local line_start_row = vim.fn.getpos("v")[2]
    if vim_mode == "V" then
        local line_start_col = 0
    else
        local line_start_col = vim.fn.getpos("v")[3]
    end


    local line_end_row = vim.fn.getpos(".")[2]
    if vim_mode == "V" then
        local line_start_col = vim.fn.col(line_end_row)
    else
        local line_start_col = vim.fn.getpos(".")[3]
    end

    local obj = {
        line_start_row = line_start_row,
        linse_start_col = line_start_col,
        line_end_row = line_end_row,
        line_end_col = line_end_col,
    }
    setmetatable(obj, self)
    return obj
end

---@class JournalEntry
---@field title string
---@field relevent_areas CodeRange[]
---@field date string

---@class Journal
---@field entries JournalEntry[]
---@field current_entry JournalEntry | nil
local Journal = {}

function Journal:new()
    local obj = { entries = {} }
    setmetatable(obj, self)
    self.__index = self
    return obj
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
    local test = CodeRange:new()
    print(vim.inspect(test))
end

navigator.setup({})

vim.keymap.set('v', 'mmm', navigator.test, {})

return navigator
