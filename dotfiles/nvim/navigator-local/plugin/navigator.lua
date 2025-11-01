local navigator = {}

---------------------------------------------------
---------------------------------------------------
-- Definition of state for the plugin
---------------------------------------------------
---------------------------------------------------

---@class CodeRange
local CodeRange = {}

---@param a integer
---@param b integer
---@return CodeRange
function CodeRange.new(a, b)
    return setmetatable({ a, b }, { __index = CodeRange })
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


function Journal:add_entry(entry)
    table.insert(self.entries, entry)
end


function Journal:explore()
    print("Not yet implemented")
end

---------------------------------------------------
---------------------------------------------------
-- Misc setup 
-------------------------------------------------
---------------------------------------------------

navigator.setup = function(opts)
    opts = opts or {}
    -- Initialize state, commands, keymaps here
    vim.api.nvim_create_user_command('NavigatorExplore', navigator.explore, {})
end

navigator.explore = function()
    -- Your code navigation logic
end

return navigator
