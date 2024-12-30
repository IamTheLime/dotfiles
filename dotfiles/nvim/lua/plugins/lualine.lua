<<<<<<< Updated upstream
-- return {
--     'nvim-lualine/lualine.nvim', -- Statusline
--     opts = {
--         theme = 'tokyonight-night',
--         options = {
--             icons_enabled = true,
--             section_separators = { left = '░', right = '░' },
--             component_separators = { left = '|', right = '|' },
--             disabled_filetypes = {}
--         },
--         sections = {
--             lualine_a = { 'mode' },
--             lualine_b = { 'branch', 'diff' },
--             lualine_c = { {
--                 'filename',
--                 file_status = true, -- displays file status (readonly status, modified status)
--                 path = 1            -- 0 = just filename, 1 = relative path, 2 = absolute path
--             } },
--             lualine_x = {
--                 {
--                     'diagnostics',
--                     sources = { "nvim_diagnostic" },
--                     symbols = {
--                         error = ' ',
--                         warn = ' ',
--                         info = ' ',
--                         hint = ' '
--                     }
--                 },
--                 'encoding',
--                 'filetype'
--             },
--             lualine_y = { 'progress' },
--             lualine_z = { 'location' }
--         },
--         inactive_sections = {
--             lualine_a = {},
--             lualine_b = {},
--             lualine_c = { {
--                 'filename',
--                 file_status = true, -- displays file status (readonly status, modified status)
--                 path = 1            -- 0 = just filename, 1 = relative path, 2 = absolute path
--             } },
--             lualine_x = { 'location' },
--             lualine_y = { 'buffers' },
--             lualine_z = {}
--         },
--         tabline = {},
--         extensions = { 'fugitive' }
--     }
-- }


local colors = {
    blue   = '#80a0ff',
    cyan   = '#79dac8',
    black  = '#080808',
    white  = '#c6c6c6',
    red    = '#ff5189',
    violet = '#d183e8',
    grey   = '#303030',
}

local bubbles_theme = {
    normal = {
        a = { fg = colors.black, bg = colors.violet },
        b = { fg = colors.white, bg = colors.grey },
        c = { fg = colors.white },
    },

    insert = { a = { fg = colors.black, bg = colors.blue } },
    visual = { a = { fg = colors.black, bg = colors.cyan } },
    replace = { a = { fg = colors.black, bg = colors.red } },

    inactive = {
        a = { fg = colors.white, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.white },
    },
}

return {
    "nvim-lualine/lualine.nvim",
    config = function()
        require("lualine").setup({
            options = {
                theme = "horizon",
                component_separators = "",
                section_separators = { left = "", right = "" },
            },
            sections = {
                lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
                lualine_b = { "filename", "branch" },
                lualine_c = {
                    "%=", --[[ add your center compoentnts here in place of this comment ]]
                },
                lualine_x = {},
                lualine_y = { "filetype", "progress" },
                lualine_z = {
                    { "location", separator = { right = "" }, left_padding = 2 },
                },
            },
            inactive_sections = {
                lualine_a = { "filename" },
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = { 'buffers' },
                lualine_z = { "location" },
            },
            tabline = {},
            extensions = {},
        })
    end,
||||||| Stash base
return {
    'nvim-lualine/lualine.nvim', -- Statusline
    opts = {
        theme = 'tokyonight-night',
        options = {
            icons_enabled = true,
            section_separators = { left = '░', right = '░' },
            component_separators = { left = '|', right = '|' },
            disabled_filetypes = {}
        },
        sections = {
            lualine_a = { 'mode' },
            lualine_b = { 'branch', 'diff' },
            lualine_c = { {
                'filename',
                file_status = true, -- displays file status (readonly status, modified status)
                path = 1            -- 0 = just filename, 1 = relative path, 2 = absolute path
            } },
            lualine_x = {
                {
                    'diagnostics',
                    sources = { "nvim_diagnostic" },
                    symbols = {
                        error = ' ',
                        warn = ' ',
                        info = ' ',
                        hint = ' '
                    }
                },
                'encoding',
                'filetype'
            },
            lualine_y = { 'progress' },
            lualine_z = { 'location' }
        },
        inactive_sections = {
            lualine_a = {},
            lualine_b = {},
            lualine_c = { {
                'filename',
                file_status = true, -- displays file status (readonly status, modified status)
                path = 1            -- 0 = just filename, 1 = relative path, 2 = absolute path
            } },
            lualine_x = { 'location' },
            lualine_y = { 'buffers' },
            lualine_z = {}
        },
        tabline = {},
        extensions = { 'fugitive' }
    }
=======
-- return {
--     'nvim-lualine/lualine.nvim', -- Statusline
--     opts = {
--         theme = 'tokyonight-night',
--         options = {
--             icons_enabled = true,
--             section_separators = { left = '░', right = '░' },
--             component_separators = { left = '|', right = '|' },
--             disabled_filetypes = {}
--         },
--         sections = {
--             lualine_a = { 'mode' },
--             lualine_b = { 'branch', 'diff' },
--             lualine_c = { {
--                 'filename',
--                 file_status = true, -- displays file status (readonly status, modified status)
--                 path = 1            -- 0 = just filename, 1 = relative path, 2 = absolute path
--             } },
--             lualine_x = {
--                 {
--                     'diagnostics',
--                     sources = { "nvim_diagnostic" },
--                     symbols = {
--                         error = ' ',
--                         warn = ' ',
--                         info = ' ',
--                         hint = ' '
--                     }
--                 },
--                 'encoding',
--                 'filetype'
--             },
--             lualine_y = { 'progress' },
--             lualine_z = { 'location' }
--         },
--         inactive_sections = {
--             lualine_a = {},
--             lualine_b = {},
--             lualine_c = { {
--                 'filename',
--                 file_status = true, -- displays file status (readonly status, modified status)
--                 path = 1            -- 0 = just filename, 1 = relative path, 2 = absolute path
--             } },
--             lualine_x = { 'location' },
--             lualine_y = { 'buffers' },
--             lualine_z = {}
--         },
--         tabline = {},
--         extensions = { 'fugitive' }
--     }
-- }
--
---- Bubbles config for lualine
-- Author: lokesh-krishna
-- MIT license, see LICENSE for more details.

-- stylua: ignore
local colors = {
    blue   = '#80a0ff',
    cyan   = '#79dac8',
    black  = '#080808',
    white  = '#c6c6c6',
    red    = '#ff5189',
    violet = '#d183e8',
    grey   = '#303030',
}

local bubbles_theme = {
    normal = {
        a = { fg = colors.black, bg = colors.violet },
        b = { fg = colors.white, bg = colors.grey },
        c = { fg = colors.white },
    },

    insert = { a = { fg = colors.black, bg = colors.blue } },
    visual = { a = { fg = colors.black, bg = colors.cyan } },
    replace = { a = { fg = colors.black, bg = colors.red } },

    inactive = {
        a = { fg = colors.white, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.white },
    },
}

return {
    "nvim-lualine/lualine.nvim",
    config = function()
        require("lualine").setup({
            options = {
                theme = "horizon",
                component_separators = "",
                section_separators = { left = "", right = "" },
            },
            sections = {
                lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
                lualine_b = { "filename", "branch" },
                lualine_c = {
                    "%=", --[[ add your center compoentnts here in place of this comment ]]
                },
                lualine_x = {},
                lualine_y = { "filetype", "progress" },
                lualine_z = {
                    { "location", separator = { right = "" }, left_padding = 2 },
                },
            },
            inactive_sections = {
                lualine_a = { "filename" },
                lualine_b = {},
                lualine_c = {},
                lualine_x = {},
                lualine_y = {},
                lualine_z = { "location" },
            },
            tabline = {},
            extensions = {},
        })
    end,
>>>>>>> Stashed changes
}
