-- All snacks.nvim configuration is contained in this single file.
-- Delete this file to remove the plugin entirely.
return {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
        animate = { enabled = false },
        scroll  = { enabled = false },
        indent  = { enabled = true, animate = { enabled = false } },
        dim     = { enabled = false },
        picker  = { enabled = true },
        gh      = { enabled = true },
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
    },
}
