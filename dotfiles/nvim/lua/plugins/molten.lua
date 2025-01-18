return {
    "benlubas/molten-nvim",
    version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
    build = ":UpdateRemotePlugins",
    init = function()
        -- this is an example, not a default. Please see the readme for more configuration options
        vim.g.molten_output_win_max_height = 12


        vim.keymap.set("n", "<localleader>ip", function()
            local venv = os.getenv("VIRTUAL_ENV")
            if venv ~= nil then
                -- in the form of /home/benlubas/.virtualenvs/VENV_NAME
                venv = string.match(venv, "/.+/(.+)")
                vim.cmd(("MoltenInit %s"):format(venv))
            else
                vim.cmd("MoltenInit python3")
            end
        end, { desc = "Initialize Molten for python3", silent = true }
        )
    end,
}
