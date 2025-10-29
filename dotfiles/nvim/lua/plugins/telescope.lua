return {
    'nvim-telescope/telescope.nvim',
    config = function()
        local telescope = require("telescope")
        local actions = require('telescope.actions')
        local builtin = require("telescope.builtin")

        local function telescope_buffer_dir()
            return vim.fn.expand('%:p:h')
        end

        local fb_actions = require "telescope".extensions.file_browser.actions
        telescope.setup {
            defaults = {
                wrap_results = true,
                prompt_prefix = "Search 🔍  ",
                mappings = {
                    i = {
                        ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
                    },
                    n = {
                        ["q"] = actions.close,
                        ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
                    },
                },
                vimgrep_arguments = {
                    "rg",
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                    "--hidden",
                },
            },
        }

        vim.keymap.set('n', ';f',
            function()
                builtin.find_files({
                    no_ignore = false,
                    hidden = true,
                    path_display = { "filename_first" },
                    file_ignore_patterns = { 'node_modules', '.git/', '.venv', 'node_modules' },
                    mappings = {
                        ["n"] = {
                            ["r"] = fb_actions.rename
                        },
                    }
                })
            end)
        vim.keymap.set('n', ';af',
            function()
                builtin.find_files({
                    no_ignore = false,
                    hidden = true,
                    respect_gitignore = false,
                    file_ignore_patterns = {},
                    path_display = { "filename_first" },
                    mappings = {
                        ["r"] = fb_actions.rename,
                    }
                })
            end)
        vim.keymap.set('n', ';r', function()
            builtin.live_grep({
                no_ignore = false,
                hidden = true,
                file_ignore_patterns = { '.git/', 'package-lock.json', '**/package-lock.json', '**/poetry.lock', '**/*.svg' }
            })
        end)
        vim.keymap.set('n', '<leader>\\', function()
            builtin.buffers()
        end)
        vim.keymap.set('n', ';q', function()
            builtin.quickfix()
        end)
        vim.keymap.set('n', ';;', function()
            builtin.resume()
        end)
        vim.keymap.set('n', ';t', function()
            builtin.lsp_dynamic_workspace_symbols({ symbols = { 'method', 'class', 'function' } })
        end)
        vim.keymap.set('n', ';mr', function()
            builtin.lsp_document_symbols({ symbols = { 'method', 'class', 'function' } })
        end)
        vim.keymap.set('n', ';sy', function()
            builtin.treesitter()
        end)
        vim.keymap.set('n', ';gc', function()
            builtin.git_commits()
        end)
        vim.keymap.set('n', ';e', function()
            builtin.diagnostics({ severity = { vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN } })
        end)
        vim.keymap.set('n', ';ae', function()
            builtin.diagnostics()
        end)
        vim.keymap.set('n', ';km', function()
            builtin.keymaps()
        end, { desc = 'Search keymaps' })
    end
}
