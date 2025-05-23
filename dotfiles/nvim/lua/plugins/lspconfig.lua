return {
    -- LSP Support
    'neovim/nvim-lspconfig',                     -- Required
    dependencies = {
        { 'williamboman/mason.nvim' },           -- Optional
        { 'williamboman/mason-lspconfig.nvim' }, -- Optional

        -- Autocompletion
        { 'hrsh7th/nvim-cmp' },         -- Required
        { 'hrsh7th/cmp-nvim-lsp' },     -- Required
        { 'hrsh7th/cmp-buffer' },       -- Optional
        { 'hrsh7th/cmp-path' },         -- Optional
        { 'saadparwaiz1/cmp_luasnip' }, -- Optional
        { 'hrsh7th/cmp-nvim-lua' },     -- Optional

        -- Snippets
        { 'L3MON4D3/LuaSnip' },             -- Required

        { 'rafamadriz/friendly-snippets' }, -- Optional
        { 'ray-x/lsp_signature.nvim' },
        { 'onsails/lspkind-nvim' },         -- vscode-like pictograms
    },
    config = function()
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
                    [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
                },
                numhl = {
                    [vim.diagnostic.severity.WARN] = 'WarningMsg',
                },
            },
        })
        local lsp_config = require("lspconfig")
        local lsp_defconf = lsp_config.util.default_config
        local lspkind = require("lspkind")

        lsp_defconf.capabilities = vim.tbl_deep_extend(
            "force",
            lsp_defconf.capabilities,
            require("cmp_nvim_lsp").default_capabilities()
        )

        vim.api.nvim_create_autocmd('LspAttach', {
            desc = "LSP actions",
            callback = function(event)
                local opts = { buffer = event.buf }
                vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
                vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
                vim.keymap.set('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
                vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
                vim.keymap.set('n', 'go', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
                vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
                vim.keymap.set('n', 'gs', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
                vim.keymap.set('n', '<F2>', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
                vim.keymap.set({ 'n', 'x' }, '<F3>', '<cmd>lua vim.lsp.buf.format({async = true})<cr>', opts)
                vim.keymap.set('n', '<F4>', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)

                -- Open diagnostics
                vim.keymap.set({ 'n' }, 'gl', function()
                    vim.diagnostic.open_float()
                end)

                -- Format
                vim.keymap.set({ 'n', 'x' }, ';gfm', function()
                    vim.lsp.buf.format({ async = true, timeout_ms = 1000, bufnr = bufnr })
                end)

                vim.keymap.set('n', 'gtr', '<cmd>Telescope lsp_references<cr>', { buffer = false })
            end
        })

        require('mason').setup({})

        vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
            pattern = "*.gitlab-ci*.{yml,yaml}",
            callback = function()
                vim.bo.filetype = "yaml.gitlab"
            end,
        })

        local border = {
            { "🭽", "FloatBorder" },
            { "▔", "FloatBorder" },
            { "🭾", "FloatBorder" },
            { "▕", "FloatBorder" },
            { "🭿", "FloatBorder" },
            { "▁", "FloatBorder" },
            { "🭼", "FloatBorder" },
            { "▏", "FloatBorder" },
        }

        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        require("mason-lspconfig").setup(
            {
                ensure_installed = {},
                automatic_enable = true,
                handlers = {

                    ["yamlls"] = function()
                        require("lspconfig").yamlls.setup({
                            on_attach = function(client, bufnr)
                                client.server_capabilities.documentFormattingProvider = true
                            end,
                            capabilities = capabilities,
                            settings = {
                                yaml = {
                                    format = {
                                        enable = true,
                                    },
                                    schemaStore = {
                                        enable = true,
                                    },
                                },
                            },
                        })
                    end,

                    ["pyright"] = function()
                        require("lspconfig").pyright.setup({
                            on_attach = function(client, bufnr)
                                print("PYTHON")
                            end,
                            capabilities = capabilities,
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
                    end,

                    ["lua_ls"] = function()
                        require("lspconfig").lua_ls.setup({
                            capabilities = capabilities,
                            settings = {
                                Lua = {
                                    diagnostics = {
                                        globals = { "vim" },
                                    },
                                },
                            },
                        })
                    end,

                    ["angularls"] = function()
                        require("lspconfig").angularls.setup({
                            capabilities = capabilities,
                            filetypes = { "angular.html" },
                        })
                    end,

                    ["tailwindcss"] = function()
                        require("lspconfig").tailwindcss.setup({
                            capabilities = capabilities,
                            filetypes = { "angular.html" },
                        })
                    end,

                    ["zls"] = function()
                        require("lspconfig").zls.setup({
                            capabilities = capabilities,
                            settings = {
                                zls = {
                                    enable_build_on_save = true,
                                    build_on_save_step = "check",
                                },
                            },
                        })
                    end,
                },
            })

        local status, cmp = pcall(require, "cmp")
        if (not status) then
            return
        end


        require('luasnip.loaders.from_snipmate').lazy_load()
        require('luasnip.loaders.from_vscode').lazy_load()
        cmp.setup({
            sources = {
                { name = 'nvim_lsp' },
                { name = 'path' },
                { name = 'luasnip' },
            },
            snippet = {
                expand = function(args)
                    vim.snippet.expand(args.body)
                end,
            },
            formatting = {
                -- changing the order of fields so the icon is the first
                fields = { 'menu', 'abbr', 'kind' },
                format = lspkind.cmp_format(),
            },
            mapping = cmp.mapping.preset.insert({
                ['<CR>'] = cmp.mapping.confirm({ select = false }),
                ['<C-Space>'] = cmp.mapping.complete(),
                ['<C-d>'] = cmp.mapping.scroll_docs(-4),
                ['<C-u>'] = cmp.mapping.scroll_docs(4),
            })
        })

        vim.api.nvim_create_autocmd("FileType", {
            pattern = { "sql", "mysql", "plsql" },
            callback = function()
                cmp.setup.buffer({ sources = { { name = 'vim-dadbod-completion' } } })
            end,
        })

        local status, lsp_signature = pcall(require, "lsp_signature")
        if (not status) then return end

        lsp_signature.setup({
            bind = true, -- This is mandatory, otherwise border config won't get registered.
            handler_opts = {
                border = "single",
            },
            always_trigger = true, -- sometime show signature on new line or in middle of parameter can be confusing, set it to false for #58
            toggle_key = '<C-s>',  -- toggle signature on and off in insert mode,  e.g. toggle_key = '<M-x>'
            timer_interval = 100,
            transparency = 100,
            hi_parameter = "LspSignatureActiveParameter", -- how your parameter will be highlight
        })

        -- Ensures that the treesitter tockens priority is higher than then
        -- lsp priority otherwise it will generate this jarring color changing effectV
        vim.highlight.priorities.semantic_tokens = 95

        lspkind.init({
            -- enables text annotations
            --
            -- default: true
            mode = 'text_symbol',

            -- default symbol map
            -- can be either 'default' (requires nerd-fonts font) or
            -- 'codicons' for codicon preset (requires vscode-codicons font)
            --
            -- default: 'default'
            preset = 'codicons',
            -- override preset symbols
            --
            -- default: {}
            symbol_map = {
                Text = "T",
                Method = " ",
                Function = " ",
                Constructor = " ",
                Field = "ﰠ ",
                Variable = " ",
                Class = "ﴯ ",
                Interface = " ",
                Module = " ",
                Property = "ﰠ ",
                Unit = "塞 ",
                Value = " ",
                Enum = " ",
                Keyword = " ",
                Snippet = " ",
                Color = " ",
                File = " ",
                Reference = " ",
                Folder = " ",
                EnumMember = " ",
                Constant = " ",
                Struct = "פּ ",
                Event = " ",
                Operator = " ",
                TypeParameter = " "
            },
        })
    end
}
