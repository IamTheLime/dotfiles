local navigator = {}

---------------------------------------------------
---------------------------------------------------
-- Definition of state for the plugin
---------------------------------------------------
---------------------------------------------------

---@class CodeRange
---@field line_start integer
---@field line_end integer
---@field column_start integer
---@field column_end integer
local CodeRange = {}


---Holds the Value for
---@param line_start integer
---@param line_end integer
---@param column_start integer
---@param column_end integer
---@return CodeRange
function CodeRange:new(line_start, line_end, column_start, column_end)
    local obj = {
        line_start = line_start,
        line_end = line_end,
        column_start = column_start,
        column_end = column_end,
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
    vim.api.nvim_create_user_command('NavigatorExplore', navigator.explore, {})
end

navigator.explore = function(opts)
    -- Your code navigation logic
    print(vim.inspect(vim.fn.getpos("v")), vim.inspect(vim.fn.getpos(".")))
    -- print(vim.inspect(vim.api.nvim_buf_get_mark(0, '<')))
end

navigator.setup({})

vim.keymap.set('v', 'nnn', navigator.explore, {})
return navigator
