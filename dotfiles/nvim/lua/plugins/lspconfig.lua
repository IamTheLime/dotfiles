return {
    -- LSP Support
    'neovim/nvim-lspconfig',
    dependencies = {
        { 'williamboman/mason.nvim' },
        { 'williamboman/mason-lspconfig.nvim' },
        { 'saghen/blink.cmp' },
    },
    config = function()
        local kotlin_lsp = require("lima_the_lime.kotlin_lsp")

        -- Set to true to test upstream kotlin-lsp without the workaround
        -- patches (jar/jrt navigation, jar-grep fallback, blink-cmp
        -- textEdit stripping). The kotlin_lsp server is still registered.
        vim.g.kotlin_lsp_barebones = false

        vim.opt.signcolumn = 'yes'

        vim.diagnostic.config({
            signs = {
                text = {
                    [vim.diagnostic.severity.ERROR] = '',
                    [vim.diagnostic.severity.WARN] = '',
                    [vim.diagnostic.severity.INFO] = '',
                    [vim.diagnostic.severity.HINT] = '',
                },
                linehl = {
                    -- [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
                },
                numhl = {
                    [vim.diagnostic.severity.WARN] = 'WarningMsg',
                },
            },
        })
        -- Apply blink.cmp capabilities to all LSP servers via wildcard config
        vim.lsp.config("*", {
            capabilities = require("blink.cmp").get_lsp_capabilities(),
        })

        vim.api.nvim_create_autocmd('LspAttach', {
            desc = "LSP actions",
            callback = function(event)
                local opts = { buffer = event.buf }
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if client and client:supports_method('textDocument/inlayHint') then
                    vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
                end
                vim.keymap.set('n', 'K', function()
                    vim.lsp.buf.hover({ border = "single", title = " Hover ", title_pos = "center" })
                end, opts)
                vim.keymap.set({ 'n', 'i' }, '<C-s>', function()
                    vim.lsp.buf.signature_help({ border = "single", title = " Signature Help ", title_pos = "center" })
                end, opts)
                vim.keymap.set('n', 'gd', function()
                    kotlin_lsp.goto_location('textDocument/definition', event.buf)
                end, opts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', 'go', function()
                    kotlin_lsp.goto_location('textDocument/typeDefinition', event.buf)
                end, opts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                vim.keymap.set('n', 'gs', function()
                    vim.lsp.buf.signature_help({ border = "single", title = " Signature Help ", title_pos = "center" })
                end, opts)
                vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, opts)
                vim.keymap.set({ 'n', 'x' }, '<F3>', vim.lsp.buf.format, opts)
                vim.keymap.set('n', '<F4>', vim.lsp.buf.code_action, opts)

                -- Open diagnostics
                vim.keymap.set({ 'n' }, 'gl', function()
                    vim.diagnostic.open_float({ border = "single", header = "Diagnostics" })
                end)

                -- Format
                vim.keymap.set({ 'n', 'x' }, ';gfm', function()
                    vim.lsp.buf.format({ async = true, timeout_ms = 1000, bufnr = bufnr })
                end)

                vim.keymap.set('n', 'gtr', '<cmd>Telescope lsp_references<cr>', { buffer = false })
            end
        })

        vim.api.nvim_create_user_command("InlayhintsToggle", function()
            local bufnr = vim.api.nvim_get_current_buf()
            vim.lsp.inlay_hint.enable(
                not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }),
                { bufnr = bufnr })
        end, { desc = "Toggle LSP inlay hints in the current buffer" })

        require('mason').setup({})

        vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
            pattern = "*.gitlab-ci*.{yml,yaml}",
            callback = function()
                vim.bo.filetype = "yaml.gitlab"
            end,
        })

        -- =====================================================================
        -- LSP server configurations (Neovim 0.12+ native API)
        -- =====================================================================
        kotlin_lsp.setup()

        vim.lsp.config("yamlls", {
            on_attach = function(client, bufnr)
                client.server_capabilities.documentFormattingProvider = true
            end,
            settings = {
                yaml = {
                    format = { enable = true },
                    schemaStore = { enable = true },
                },
            },
        })

        vim.lsp.config("pyright", {
            settings = {
                python = {
                    analysis = {
                        extraPaths = { ".venv" },
                        autoSearchPaths = false,
                        useLibraryCodeForTypes = true,
                        diagnosticMode = "openFilesOnly",
                    },
                },
            },
            single_file_support = true,
            flags = {
                debounce_text_changes = 250,
            },
        })

        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    diagnostics = {
                        globals = { "vim" },
                    },
                },
            },
        })

        vim.lsp.config("bqls", {
            filetypes = { "sql", "mysql" },
            settings = {
                project_id = "urbanjungle-data",
                location = "EU",
            },
        })

        vim.lsp.config("angularls", {
            filetypes = { "angular.html" },
        })

        vim.lsp.config("tailwindcss", {
            filetypes = { "angular.html" },
        })

        vim.lsp.config("zls", {
            settings = {
                zls = {
                    enable_build_on_save = true,
                },
            },
        })

        vim.lsp.enable({
            "kotlin_lsp", "yamlls", "pyright", "lua_ls",
            "bqls", "angularls", "tailwindcss", "zls",
        })

        require("mason-lspconfig").setup({
            automatic_enable = true,
        })

        local default_pyright_mode = "openFilesOnly"
        local function toggle_pyright_workspace_mode()
            local bufnr = vim.api.nvim_get_current_buf()
            for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
                if client.name == "pyright" then
                    local curr_mode = client.config.settings.python.analysis.diagnosticMode

                    local new_mode = default_pyright_mode
                    if curr_mode == default_pyright_mode then
                        new_mode = "workspace"
                    else
                        new_mode = default_pyright_mode
                    end

                    client.config.settings = client.config.settings or {}
                    client.config.settings.python = client.config.settings.python or {}
                    client.config.settings.python.analysis = client.config.settings.python.analysis or {}
                    client.config.settings.python.analysis.diagnosticMode = new_mode
                    client.notify("workspace/didChangeConfiguration", {
                        settings = client.config.settings,
                    })

                    vim.notify("Pyright workspace mode set to: " .. new_mode, vim.log.levels.INFO)
                end
            end
        end

        vim.keymap.set("n", "<leader>wm", function() toggle_pyright_workspace_mode() end)

        -- Ensures that the treesitter tokens priority is higher than the
        -- lsp priority otherwise it will generate this jarring color changing effect
        vim.highlight.priorities.semantic_tokens = 95
    end
}
