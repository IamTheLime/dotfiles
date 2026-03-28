local active_integration = "claudecode" -- "claudecode" or "opencode"

local integrations = {}

if active_integration == "claudecode" then
    integrations = {
        {
            "coder/claudecode.nvim",
            dependencies = {
                { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
            },
            opts = {
                terminal = {
                    split_side = "right",
                    split_width_percentage = 0.4,
                    provider = "snacks",
                    auto_close = false,
                },
                diff = {
                    layout = "vertical",
                },
            },
            config = function(_, opts)
                require("claudecode").setup(opts)

                vim.o.autoread = true

                local keymaps = {
                    { modes = { "n", "v" }, lhs = "<C-q>",      rhs = ":<C-u>ClaudeCodeSend<CR>",       desc = "Send selection to Claude" },
                    { modes = { "n", "t" }, lhs = "<C-.>",       rhs = "<cmd>ClaudeCodeFocus<CR>",        desc = "Toggle/focus Claude terminal" },
                    { modes = { "n", "v" }, lhs = "<leader>aa",  rhs = "<cmd>ClaudeCodeAdd %<CR>",        desc = "Add current file to Claude" },
                    { modes = { "n" },      lhs = "<leader>as",  rhs = "<cmd>ClaudeCodeSelectModel<CR>",  desc = "Select Claude model" },
                    { modes = { "n" },      lhs = "<leader>ar",  rhs = "<cmd>ClaudeCode --resume<CR>",    desc = "Resume a Claude session" },
                    { modes = { "n" },      lhs = "<leader>ac",  rhs = "<cmd>ClaudeCode --continue<CR>",  desc = "Continue last Claude session" },
                }

                for _, km in ipairs(keymaps) do
                    vim.keymap.set(km.modes, km.lhs, km.rhs, { desc = km.desc })
                end

                vim.keymap.set("n", "<leader>a?", function()
                    local lines = {}
                    for _, km in ipairs(keymaps) do
                        local mode_str = table.concat(km.modes, ",")
                        table.insert(lines, string.format("%-6s  %-14s  %s", mode_str, km.lhs, km.desc))
                    end
                    table.insert(lines, string.format("%-6s  %-14s  %s", "n", "<leader>a?", "Show this help"))
                    vim.ui.select(lines, { prompt = "Claude Code keybinds:" }, function() end)
                end, { desc = "Show Claude Code keybind help" })
            end,
        },
    }
elseif active_integration == "opencode" then
    integrations = {
        {
            "NickvanDyke/opencode.nvim",
            dependencies = {
                { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
            },
            config = function()
                vim.g.opencode_opts = {}
                vim.o.autoread = true

                vim.keymap.set({ "n", "x" }, "<C-q>", function() require("opencode").ask("@this: ", { submit = true }) end,
                    { desc = "Ask opencode" })
                vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end,
                    { desc = "Execute opencode action…" })
                vim.keymap.set({ "n", "x" }, "ga", function() require("opencode").prompt("@this") end,
                    { desc = "Add to opencode" })
                vim.keymap.set({ "n", "t" }, "<C-.>", function() require("opencode").toggle() end,
                    { desc = "Toggle opencode" })
                vim.keymap.set('n', '+', '<C-a>', { desc = 'Increment', noremap = true })
                vim.keymap.set('n', '-', '<C-x>', { desc = 'Decrement', noremap = true })
            end,
        },
    }
end

return integrations
