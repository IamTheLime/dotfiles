return {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
        { "<Leader>mt", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown render" },
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
        heading = {
            width = 'block',
            right_pad = 2,
        },
        code = {
            width = 'block',
            right_pad = 2,
        },
        dash = {
            width = 80,
        },
        overrides = {
            filetype = {
                markdown = {
                    win_options = {
                        -- Soft-wrap prose at word boundaries without changing the file.
                        wrap = { default = vim.o.wrap, rendered = true },
                        linebreak = { default = vim.o.linebreak, rendered = true },
                        breakindent = { default = vim.o.breakindent, rendered = true },
                    },
                },
            },
        },
        latex = {
            enabled = true,
            converter = { 'utftex', 'latex2text' },
        },
        bullet = {
            right_pad = 0,
        }
    },
}
