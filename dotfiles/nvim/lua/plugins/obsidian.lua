return {
    "epwalsh/obsidian.nvim",
    lazy = true,
    event = {
        -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
        -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
        "BufReadPre /Users/tiagolima/Library/CloudStorage/GoogleDrive-tafl.tiagolima@gmail.com/Other computers/My computer/notes/tiago's vault/**.md",
        "BufNewFile /Users/tiagolima/Library/CloudStorage/GoogleDrive-tafl.tiagolima@gmail.com/Other computers/My computer/notes/tiago's vault/**.md",
    },
    dependencies = {
        -- Required.
        "nvim-lua/plenary.nvim",

        -- see below for full list of optional dependencies 👇
    },
    opts = {

        dir =
        "/Users/tiagolima/Library/CloudStorage/GoogleDrive-tafl.tiagolima@gmail.com/Other computers/My computer/notes/tiago's vault"
        -- see below for full list of options 👇
    },
}
