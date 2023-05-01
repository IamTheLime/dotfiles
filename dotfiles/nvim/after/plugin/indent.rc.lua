local status, lsp_signature = pcall(require, "rose-pine")
if (not status) then return end

local util = {}

local function byte(value, offset)
    return bit.band(bit.rshift(value, offset), 0xFF)
end
local function rgb(color)
    color = vim.api.nvim_get_color_by_name(color)

    if color == -1 then
        color = vim.opt.background:get() == 'dark' and 000 or 255255255
    end

    return { byte(color, 16), byte(color, 8), byte(color, 0) }
end

local function parse_color(color)
    if color == nil then
        return print('invalid color')
    end

    color = color:lower()

    if not color:find('#') and color ~= 'none' then
        color = require('rose-pine.palette')[color]
            or vim.api.nvim_get_color_by_name(color)
    end

    return color
end

---@param fg string foreground color
---@param bg string background color
---@param alpha number number between 0 (background) and 1 (foreground)
util.blend = function(fg, bg, alpha)
    local fg_rgb = rgb(parse_color(fg))
    local bg_rgb = rgb(parse_color(bg))

    local function blend_channel(i)
        local ret = (alpha * fg_rgb[i] + ((1 - alpha) * bg_rgb[i]))
        return math.floor(math.min(math.max(0, ret), 255) + 0.5)
    end

    return string.format(
        '#%02X%02X%02X',
        blend_channel(1),
        blend_channel(2),
        blend_channel(3)
    )
end

---@param group string
---@param color table<string, any>
util.highlight = function(group, color)
    local fg = color.fg and parse_color(color.fg) or 'none'
    local bg = color.bg and parse_color(color.bg) or 'none'

    if
        color.blend ~= nil
        and (color.blend >= 0 or color.blend <= 100)
    then
        fg = util.blend(fg, parse_color('base') or '', color.blend / 100)
    end

    local colours = {}


    if fg ~= nil then
        colours["fg"] = fg
    end

    colours["sp"] = "none"
    color = vim.tbl_extend('force', color, colours)
    vim.api.nvim_set_hl(0, group, color)
end



local h = util.highlight
local b = util.blend
vim.opt.list = true
vim.opt.listchars = {
    -- eol = '↲',
    -- tab = '▸ ',
    trail = ' '
}
vim.opt.termguicolors = true
h('IndentBlanklineIndent1', { fg = "#E06C75", blend = 10 })
h('IndentBlanklineIndent2', { fg = "#E5C07B", blend = 10 })
h('IndentBlanklineIndent3', { fg = "#98C379", blend = 10 })
h('IndentBlanklineIndent4', { fg = "#56B6C2", blend = 10 })
h('IndentBlanklineIndent5', { fg = "#61AFEF", blend = 10 })
h('IndentBlanklineIndent6', { fg = "#C678DD", blend = 10 })


require("indent_blankline").setup {
    space_char_blankline = " ",
    char_highlight_list = {
        "IndentBlanklineIndent1",
        "IndentBlanklineIndent2",
        "IndentBlanklineIndent3",
        "IndentBlanklineIndent4",
        "IndentBlanklineIndent5",
        "IndentBlanklineIndent6",
    },
    space_char_highlight_list = {
        "IndentBlanklineIndent1",
        "IndentBlanklineIndent2",
        "IndentBlanklineIndent3",
        "IndentBlanklineIndent4",
        "IndentBlanklineIndent5",
        "IndentBlanklineIndent6",
    },
    show_trailing_blankline_indent = true,
    show_current_context = false,
}
