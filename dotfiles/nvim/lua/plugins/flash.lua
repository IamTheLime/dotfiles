return {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
    keys = {
        { "ss", mode = { "n", "o", "x" }, function() require("flash").jump() end, desc = "Flash" },
        {
            "SS",
            mode = { "n", "o", "x" },
            function() require("flash").treesitter() end,
            desc =
            "Flash Treesitter"
        },
        {
            "rr",
            mode = "o",
            function() require("flash").remote() end,
            desc =
            "Remot lash"
        },
        {
            "RR",
            mode = { "o", "x" },
            function() require("flash").treesitter_search() end,
            desc =
            "Treesitter Search"
        },
        {
            "<c-s>",
            mode = { "c" },
            function() require("flash").toggle() end,
            desc =
            "Toggle Flash Search"
        },
    },
}
