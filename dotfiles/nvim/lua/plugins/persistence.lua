return {
    "folke/persistence.nvim",
    lazy = false,
    event = "BufReadPre", -- this will only start session saving when an actual file was opened
    keys = {
        {
            "<leader>qs",
            mode = { "n", "o", "x" },
            function()
                require('persistence').load()
            end,
            desc = "Persistence"
        },
        {
            "<leader>ql",
            mode = { "n", "o", "x" },
            function()
                require('persistence').load({ last = true })
            end,
            desc = "Persistence"
        },
    },
    opts = {
        dir = vim.fn.expand(vim.fn.stdpath("state") .. "/sessions/"), -- directory where session files are saved
        options = { "buffers", "curdir", "tabpages", "winsize" },     -- sessionoptions used for saving
        pre_save = nil,                                               -- a function to call before saving the session
    }
}
