return {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
        { "<Leader>mt", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown render" },
    },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
        latex = {
            enabled = true,
            converter = { 'utftex', 'latex2text' },
        },
        bullet = {
            right_pad = 1,
        }
    },
}
