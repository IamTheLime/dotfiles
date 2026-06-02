return {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    opts = {
        providers = { "lsp", "treesitter", "regex" },
        delay = 0,
        large_file_cutoff = 2000,
        filetypes_denylist = {
            "lazy",
            "mason",
            "snacks_dashboard",
            "snacks_notif",
        },
    },
    config = function(_, opts)
        require("illuminate").configure(opts)
    end,
}
