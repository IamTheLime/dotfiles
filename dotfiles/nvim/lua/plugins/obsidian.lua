local function get_obsidian_vault_location()
    if vim.loop.os_uname().sysname == "Darwin" then
        return
        "~/Documents/obsidian/tiago_vault/"
    end
    return "~/Obsidian/tiago_vault/"
end



return {
    "epwalsh/obsidian.nvim",
    lazy = true,
    event = {
        -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
        -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
        "BufReadPre " .. get_obsidian_vault_location() .. "/**.md",
        "BufNewFile " .. get_obsidian_vault_location() .. "/**.md",
    },
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    opts = {
        dir = get_obsidian_vault_location()
        -- see below for full list of options 👇
    },
    keys = {
        {
            "<leader>nn",
            function()
                vim.cmd("ObsidianNew")
            end,
            desc = "Obsidian create"
        },
        {
            "<leader>so",
            function()
                vim.cmd("ObsidianSearch")
            end,
            desc = "Obsidian create"
        },
    },
}
