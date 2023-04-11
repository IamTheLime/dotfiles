--require("indent_blankline").setup {
--  space_char_blankline = " ",
--  show_current_context = true,
--  show_current_context_start = false,
--  show_trailing_blankline_indent = false,
--}

vim.opt.termguicolors = true
vim.opt.winblend = 30
vim.opt.pumblend = 30
--vim.cmd [[highlight IndentBlanklineIndent1 guibg=#261619 gui=nocombine]]
--vim.cmd [[highlight IndentBlanklineIndent2 guibg=#211725 gui=nocombine]]
--vim.cmd [[highlight IndentBlanklineIndent3 guibg=#171825 gui=nocombine]]
--vim.cmd [[highlight IndentBlanklineIndent4 guibg=#171825 gui=nocombine]]
--vim.cmd [[highlight IndentBlanklineIndent5 guibg=#13241b gui=nocombine]]
--vim.cmd [[highlight IndentBlanklineIndent6 guibg=#1e2415 gui=nocombine]]
--vim.cmd [[highlight IndentBlanklineIndent1 guibg=#E06C75 guifg=NONE gui=nocombine blend=50]]
--vim.cmd [[highlight IndentBlanklineIndent2 guibg=#E5C07B guifg=NONE gui=nocombine blend=50]]
--vim.cmd [[highlight IndentBlanklineIndent3 guibg=#98C379 guifg=NONE gui=nocombine blend=50]]
--vim.cmd [[highlight IndentBlanklineIndent4 guibg=#56B6C2 guifg=NONE gui=nocombine blend=50]]
--vim.cmd [[highlight IndentBlanklineIndent5 guibg=#61AFEF guifg=NONE gui=nocombine blend=50]]
--vim.cmd [[highlight IndentBlanklineIndent6 guibg=#C678DD guifg=NONE gui=nocombine blend=50]]
--
--require("indent_blankline").setup {
--    char = "",
--    char_highlight_list = {
--        "IndentBlanklineIndent1",
--        "IndentBlanklineIndent2",
--        "IndentBlanklineIndent3",
--        "IndentBlanklineIndent4",
--        "IndentBlanklineIndent5",
--        "IndentBlanklineIndent6",
--    },
--    space_char_highlight_list = {
--        "IndentBlanklineIndent1",
--        "IndentBlanklineIndent2",
--        "IndentBlanklineIndent3",
--        "IndentBlanklineIndent4",
--        "IndentBlanklineIndent5",
--        "IndentBlanklineIndent6",
--    },
--    show_trailing_blankline_indent = false,
--    show_current_context = true,
--}
--
--#region
local p = require('rose-pine.palette')

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

local function blend(fg, bg, alpha)
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


vim.opt.termguicolors = true
vim.cmd [[highlight IndentBlanklineIndent1 guifg=#E06C75 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent2 guifg=#E5C07B gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent3 guifg=#98C379 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent4 guifg=#56B6C2 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent5 guifg=#61AFEF gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent6 guifg=#C678DD gui=nocombine]]

vim.opt.list = true

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
    show_trailing_blankline_indent = false,
    show_current_context = true,
}
