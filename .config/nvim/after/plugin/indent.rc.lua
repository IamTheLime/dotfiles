--local h = require('rose-pine.util').highlight
--
--vim.opt.termguicolors = true
--h('IndentBlanklineIndent1', { fg = "#E06C75", blend = 10 })
--h('IndentBlanklineIndent2', { fg = "#E5C07B", blend = 10 })
--h('IndentBlanklineIndent3', { fg = "#98C379", blend = 10 })
--h('IndentBlanklineIndent4', { fg = "#56B6C2", blend = 10 })
--h('IndentBlanklineIndent5', { fg = "#61AFEF", blend = 10 })
--h('IndentBlanklineIndent6', { fg = "#C678DD", blend = 10 })
--
--vim.opt.list = true
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
--    --#space_char_highlight_list = {
--    --#    "IndentBlanklineIndent1",
--    --#    "IndentBlanklineIndent2",
--    --#    "IndentBlanklineIndent3",
--    --#    "IndentBlanklineIndent4",
--    --#    "IndentBlanklineIndent5",
--    --#    "IndentBlanklineIndent6",
--    --#},
--    show_trailing_blankline_indent = false,
--    show_current_context = true,
--}

vim.opt.termguicolors = true
vim.cmd [[highlight IndentBlanklineIndent1 guibg=#1f1f1f gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent2 guibg=#1a1a1a gui=nocombine]]
let g:indent_blankline_use_treesitter_scope = true
require("indent_blankline").setup {
    char = "",
    char_highlight_list = {
        "IndentBlanklineIndent1",
        "IndentBlanklineIndent2",
    },
    space_char_highlight_list = {
        "IndentBlanklineIndent2",
        "IndentBlanklineIndent1",
    },
    show_trailing_blankline_indent = false,
}
