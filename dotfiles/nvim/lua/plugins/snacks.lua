-- All snacks.nvim configuration is contained in this single file.
-- Delete this file to remove the plugin entirely.
return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    init = function()
        -- :GitBlameLine — current-line blame in a float (git log -L on the line).
        -- Snacks is always loaded, so Snacks.git is available when the command runs.
        vim.api.nvim_create_user_command("GitBlameLine", function()
            Snacks.git.blame_line()
        end, { desc = "Git blame — current line (snacks)" })
    end,
    ---@type snacks.Config
    opts = {
        animate = { enabled = false },
        scroll  = { enabled = false },
        indent  = { enabled = true, animate = { enabled = false } },
        dim     = { enabled = false },
        picker  = { enabled = true },
        gh      = {
            enabled = true,
            -- snacks sets foldmethod=expr + treesitter foldexpr on its GitHub
            -- buffers but leaves foldlevel at the default 0, so PR diffs open
            -- fully collapsed (you'd have to zA every time). Start unfolded;
            -- the per-file fold structure stays, so zc still works.
            wo = { foldlevel = 99 },
        },
        dashboard = {
            enabled = true,
            preset = {
                keys = {
                    { icon = " ", key = "f", desc = "Find File",      action = ":lua Snacks.dashboard.pick('files')" },
                    { icon = " ", key = "n", desc = "New File",       action = ":ene | startinsert" },
                    { icon = " ", key = "g", desc = "Find Text",      action = ":lua Snacks.dashboard.pick('live_grep')" },
                    { icon = " ", key = "r", desc = "Recent Files",   action = ":lua Snacks.dashboard.pick('oldfiles')" },
                    { icon = " ", key = "i", desc = "GitHub Issues",  action = ":lua Snacks.picker.gh_issue()" },
                    { icon = " ", key = "P", desc = "GitHub PRs",     action = ":lua Snacks.picker.gh_pr()" },
                    { icon = " ", key = "L", desc = "Lazy",           action = ":Lazy",                                  enabled = package.loaded.lazy ~= nil },
                    { icon = " ", key = "q", desc = "Quit",           action = ":qa" },
                },
            },
            sections = {
                { section = "header" },
                { section = "keys", gap = 1, padding = 1 },
                {
                    pane = 2,
                    icon = " ",
                    desc = "Browse Repo",
                    padding = 1,
                    key = "b",
                    action = function() Snacks.gitbrowse() end,
                },
                function()
                    local in_git = Snacks.git.get_root() ~= nil
                    local cmds = {
                        {
                            title = "Open Issues",
                            cmd = "gh issue list -L 3",
                            key = "i",
                            action = function() Snacks.picker.gh_issue() end,
                            icon = " ",
                            height = 7,
                        },
                        {
                            icon = " ",
                            title = "Open PRs",
                            cmd = "gh pr list -L 3",
                            key = "P",
                            action = function() Snacks.picker.gh_pr() end,
                            height = 7,
                        },
                        {
                            icon = " ",
                            title = "Git Status",
                            cmd = "git --no-pager diff --stat -B -M -C",
                            height = 10,
                        },
                    }
                    return vim.tbl_map(function(cmd)
                        return vim.tbl_extend("force", {
                            pane = 2,
                            section = "terminal",
                            enabled = in_git,
                            padding = 1,
                            ttl = 5 * 60,
                            indent = 3,
                        }, cmd)
                    end, cmds)
                end,
                { section = "startup" },
            },
        },
    },
    keys = {
        { "<leader>gd", function() Snacks.dashboard() end,                          desc = "GitHub Dashboard" },
        { "<leader>gi", function() Snacks.picker.gh_issue() end,                    desc = "GitHub Issues" },
        { "<leader>gI", function() Snacks.picker.gh_issue({ state = "all" }) end,   desc = "GitHub Issues (all)" },
        { "<leader>gp", function() Snacks.picker.gh_pr() end,                       desc = "GitHub PRs" },
        { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end,      desc = "GitHub PRs (all)" },
        -- Was git.nvim's `browse`; snacks does the same thing (visual mode picks the line range).
        { "<leader>go", function() Snacks.gitbrowse() end,                          desc = "Open in git remote", mode = { "n", "v" } },
        { "<leader>gl", function() Snacks.picker.git_log_line() end,                desc = "Git log for current line" },
    },
}
