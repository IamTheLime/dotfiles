return {
    'cryptomilk/nightcity.nvim',
    version = false,
    config = function(_, opts)
        require('nightcity').setup({
            style = "afterlife",
            terminal_colors = false, -- Use colors used when opening a `:terminal`
            invert_colors = {
                -- Invert colors for the following syntax groups
                cursor = true,
                diff = true,
                error = true,
                search = true,
                selection = false,
                signs = false,
                statusline = true,
                tabline = false,
            },
            font_style = {
                -- Style to be applied to different syntax groups
                comments = { italic = false },
                keywords = { italic = false },
                functions = { bold = false },
                variables = {},
                search = { bold = true },
            },
            on_highlights = function(groups, colors)
                groups.String = { fg = colors.green, bg = colors.none, }
                -- print(vim.inspect(groups))
            end,
        })
        vim.cmd.colorscheme('nightcity')
    end,
}

-- return {
--     "folke/tokyonight.nvim",
--     dependencies = {
--         {
--             'maxmx03/solarized.nvim',
--             lazy = false,
--             priority = 1000,
--             ---@type solarized.config
--             opts = {},
--             config = function(_, opts)
--                 vim.o.termguicolors = true
--                 vim.o.background = 'light'
--                 require('solarized').setup(opts)
--                 vim.cmd.colorscheme 'solarized'
--             end,
--         }
--
--
--     },
--     lazy = false,
--     priority = 1000,
--     -- opts = {
--     --     -- your configuration comes here
--     --     -- or leave it empty to use the default settings
--     --     style = "night",        -- The theme comes in three styles, `storm`, `moon`, a darker variant `night` and `day`
--     --     light_style = "day",    -- The theme is used when the background is set to light
--     --     transparent = false,    -- Enable this to disable setting the background color
--     --
--     --     terminal_colors = true, -- Configure the colors used when opening a `:terminal` in [Neovim](https://github.com/neovim/neovim)
--     --     styles = {
--     --         -- Style to be applied to different syntax groups
--     --         -- Value is any valid attr-list value for `:help nvim_set_hl`
--     --         comments = { italic = true },
--     --
--     --         keywords = { italic = true },
--     --         functions = {},
--     --         variables = {},
--     --         -- Background styles. Can be "dark", "transparent" or "normal"
--     --         sidebars = "dark",            -- style for sidebars, usee below
--     --         floats = "dark",              -- style for floating windows
--     --     },
--     --     sidebars = { "qf", "help" },      -- Set a darker background on sidebar-like windows. For example: `["qf", "vista_kind", "terminal", "packer"]`
--     --     day_brightness = 1,               -- Adjusts the brightness of the colors of the **Day** style. Number between 0 and 1, from dull to vibrant colors
--     --     hide_inactive_statusline = false, -- Enabling this option, will hide inactive statuslines and replace them with a thin border instead. Should work with the standard **StatusLine** and **LuaLine**.
--     --     dim_inactive = false,             -- dims inactive windows
--     --
--     --     lualine_bold = true,              -- When `true`, section headers in the lualine theme will be bold
--     --
--     --     --- You can override specific color groups to use other groups or a hex color
--     --     --- function will be called with a ColorScheme table
--     --     ---@param colors ColorScheme
--     --     on_colors = function(colors) end,
--     --
--     --     --- You can override specific highlights to use other groups or a hex color
--     --
--     --     --- function will be called with a Highlights and ColorScheme table
--     --     ---@param highlights Highlights
--     --     ---@param colors ColorScheme
--     --     on_highlights = function(highlights, colors) end,
--     -- },
--     config = function(_, opts)
--         vim.cmd("colorscheme solarized")
--         -- vim.cmd("colorscheme horizon")
--     end,
-- }
