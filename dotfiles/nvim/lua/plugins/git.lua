return {
    'dinhhuy258/git.nvim', -- For git blame & browse
    opts = {
        default_mappings = false,
        keymaps = {
            -- Open blame window
            blame = "<Leader>gb",
            -- Open file/folder in git repository
            browse = "<Leader>go",
        }
    }
}
