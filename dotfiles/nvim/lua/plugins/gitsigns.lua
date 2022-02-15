return {
    'lewis6991/gitsigns.nvim',
    -- Load on buffer read, not on first keypress: gitsigns' attach is async, so a
    -- lazy-load triggered *by* :GitBlame raced the attach and failed the first call
    -- (worked on the second). Attaching at BufReadPre means blame is always ready.
    event = { "BufReadPre", "BufNewFile" },
    init = function()
        -- :GitBlame — full-file, scroll-synced blame in a side window (all lines).
        -- Navigation-safe (this is the plugin that replaced the input-hijacking git.nvim).
        vim.api.nvim_create_user_command("GitBlame", function()
            require("gitsigns").blame()
        end, { desc = "Git blame — full file (gitsigns)" })
    end,
    keys = {
        -- Replaces dinhhuy258/git.nvim, whose blame window hijacked text input.
        { "<Leader>gb", "<cmd>Gitsigns blame<cr>",      desc = "Git blame (side window)" },
        { "<Leader>gB", "<cmd>Gitsigns blame_line<cr>", desc = "Git blame current line (popup)" },
    },
    opts = {
        signs                        = {
            add          = { text = '┃' },
            change       = { text = '┃' },
            delete       = { text = '_' },
            topdelete    = { text = '‾' },
            changedelete = { text = '~' },
            untracked    = { text = '┆' },
        },
        signs_staged                 = {
            add          = { text = '┃' },
            change       = { text = '┃' },
            delete       = { text = '_' },
            topdelete    = { text = '‾' },
            changedelete = { text = '~' },
            untracked    = { text = '┆' },
        },
        signs_staged_enable          = true,
        signcolumn                   = true, -- Toggle with `:Gitsigns toggle_signs`
        numhl                        = false, -- Toggle with `:Gitsigns toggle_numhl`
        linehl                       = false, -- Toggle with `:Gitsigns toggle_linehl`
        word_diff                    = false, -- Toggle with `:Gitsigns toggle_word_diff`
        watch_gitdir                 = {
            follow_files = true
        },
        auto_attach                  = true,
        attach_to_untracked          = false,
        current_line_blame           = false, -- Toggle with `:Gitsigns toggle_current_line_blame`
        current_line_blame_opts      = {
            virt_text = true,
            virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
            delay = 1000,
            ignore_whitespace = false,
            virt_text_priority = 100,
        },
        current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
        sign_priority                = 6,
        update_debounce              = 100,
        status_formatter             = nil, -- Use default
        max_file_length              = 40000, -- Disable if file is longer than this (in lines)
        preview_config               = {
            -- Options passed to nvim_open_win
            border = 'single',
            style = 'minimal',
            relative = 'cursor',
            row = 0,
            col = 1
        },
    }
}
