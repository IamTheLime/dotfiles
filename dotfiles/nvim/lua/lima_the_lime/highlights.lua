vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.winblend = 0
-- vim.opt.wildoptions = 'pum'
vim.opt.pumblend = 5

-- neo-tree ships NeoTreeGitIgnored as `highlight default link NeoTreeDotfile`, so
-- gitignored entries render in the same grey as dotfiles and you can't tell them
-- apart. A non-default definition wins over neo-tree's, but a colorscheme load
-- clears it, hence the autocmd.
local function neotree_filtered_highlights()
    vim.api.nvim_set_hl(0, "NeoTreeGitIgnored", { fg = "#9d7a4f", italic = true })
end

vim.api.nvim_create_autocmd("ColorScheme", {
    desc = "Keep gitignored entries visually distinct from dotfiles in neo-tree",
    callback = neotree_filtered_highlights,
})
neotree_filtered_highlights()

