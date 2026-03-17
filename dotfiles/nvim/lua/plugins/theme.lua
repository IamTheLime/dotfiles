local active_theme = "tokyonight" -- Changed from "rose-pine" to activate Tokyo Night
local themes = {
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
        if theme.name == "tokyonight" then
            theme.config = function()
                -- Configure Tokyo Night for pure black OLED experience
                require("tokyonight").setup({
                    style = "night", -- Use the night variant
                    on_colors = function(c)
                        -- Pure black backgrounds for all UI elements
                        c.bg = "#000000"
                        c.bg_dark = "#000000"
                        c.bg_float = "#000000"
                        c.bg_popup = "#000000"
                        c.bg_sidebar = "#000000"
                        c.bg_statusline = "#000000"
                    end,
                })
                vim.opt.cursorline = false
                vim.cmd("colorscheme tokyonight")

                -- Ensure lualine uses the Tokyo Night theme (now with black backgrounds)
                require("lualine").setup({ options = { theme = "tokyonight" } })
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
