local active_theme = "ember-grove"
local themes = {
    {
        dir = vim.fn.stdpath("config") .. "/themes/ember-grove",
        name = "ember-grove",
    },
    {
        "rose-pine/neovim",
        name = "rose-pine",
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
    },
    {
        "folke/tokyonight.nvim",
        name = "tokyonight",
    },
    {
        "rebelot/kanagawa.nvim",
        name = "kanagawa",
    },
}
-- Apply lazy-loading logic based on active theme
for _, theme in ipairs(themes) do
    if theme.name == active_theme then
        theme.lazy = false
        theme.priority = 1000
        if theme.name == "ember-grove" then
            theme.config = function()
                require("ember-grove").setup({ transparent = true })
                vim.cmd("colorscheme ember-grove")
            end
        elseif theme.name == "tokyonight" then
            theme.config = function()
                -- Let the terminal background show through.
                require("tokyonight").setup({
                    transparent = true,
                    styles = {
                       sidebars = "transparent",
                       floats = "transparent"
                    },
                    style = "night", -- Use the night variant
                })
                vim.opt.cursorline = false
                vim.cmd("colorscheme tokyonight")
            end
        elseif theme.name == "rose-pine" then
            theme.config = function()
                vim.cmd("colorscheme rose-pine")
                vim.api.nvim_set_hl(0, "Normal", { bg = "#16121A" })
            end
        else
            theme.config = function()
                vim.cmd("colorscheme " .. theme.name)
            end
        end
    else
        theme.lazy = true
    end
end
return themes
