return {
    "PedramNavid/dbtpal",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    ft = {
        "sql",
        "md",
        "yaml",
    },
    keys = {
        -- these keys are currently conflicting with the debug adapter
        -- { "<leader>drf", "<cmd>DbtRun<cr>" },
        -- { "<leader>drp", "<cmd>DbtRunAll<cr>" },
        -- { "<leader>dtf", "<cmd>DbtTest<cr>" },
        -- { "<leader>dm",  "<cmd>lua require('dbtpal.telescope').dbt_picker()<cr>" },
    },
    config = function()
        require("dbtpal").setup({
            path_to_dbt = "dbt",
            path_to_dbt_project = "",
            path_to_dbt_profiles_dir = vim.fn.expand("~/.dbt"),
            extended_path_search = true,
            protect_compiled_files = true,
        })
        require("telescope").load_extension("dbtpal")
    end,
}
