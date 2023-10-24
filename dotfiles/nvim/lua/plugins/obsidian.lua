local function get_obsidian_vault_location()
    if vim.loop.os_uname().sysname == "Darwin" then
        return
        "/Users/tiagolima/Library/CloudStorage/GoogleDrive-tafl.tiagolima@gmail.com/Other computers/My computer/notes/tiago_vault"
    end
    return ""
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
        -- Required.
        "nvim-lua/plenary.nvim",

        -- see below for full list of optional dependencies 👇
    },
    opts = {

        dir = get_obsidian_vault_location()
        -- see below for full list of options 👇
    },
}
