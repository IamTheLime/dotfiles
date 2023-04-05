--require("indent_blankline").setup {
--  space_char_blankline = " ",
--  show_current_context = true,
--  show_current_context_start = false,
--  show_trailing_blankline_indent = false,
--}

vim.opt.termguicolors = true
vim.cmd [[highlight IndentBlanklineIndent1 guibg=#261619 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent2 guibg=#211725 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent3 guibg=#171825 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent4 guibg=#171825 gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent5 guibg=#13241b gui=nocombine]]
vim.cmd [[highlight IndentBlanklineIndent6 guibg=#1e2415 gui=nocombine]]

require("indent_blankline").setup {
    char = "",
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
    show_trailing_blankline_indent = false,
    show_current_context = true,
}
