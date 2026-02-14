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
                    -- [vim.diagnostic.severity.ERROR] = 'ErrorMsg',
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
                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', 'go', vim.lsp.buf.type_definition, opts)
                vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                vim.keymap.set('n', 'gs', vim.lsp.buf.signature_help, opts)
                vim.keymap.set('n', '<F2>', vim.lsp.buf.rename, opts)
                vim.keymap.set({ 'n', 'x' }, '<F3>', vim.lsp.buf.format, opts)
                vim.keymap.set('n', '<F4>', vim.lsp.buf.code_action, opts)

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
                    ["bqls"] = function()
                        require("lspconfig").bqls.setup({
                            capabilities = capabilities,
                            filetypes = { "sql", "mysql" },
                            settings = {
                                project_id = "urbanjungle-data",
                                location = "EU",
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
                                },
                            },
                        })
                    end,

                    ["kotlin_lsp"] = function()
                        require("lspconfig").kotlin_lsp.setup({
                            capabilities = capabilities,
                            filetypes = { "kotlin" },
                            init_options = {
                                storagePath = vim.fn.stdpath("data") .. "/kotlin_lsp",
                            },
                            settings = {
                                kotlin = {
                                    compiler = {
                                        jvm = {
                                            target = "default"
                                        }
                                    },
                                    indexing = {
                                        enabled = true,
                                    },
                                    externalSources = {
                                        useKlsScheme = true,
                                        autoConvertToKotlin = true
                                    },
                                    completion = {
                                        snippets = {
                                            enabled = true
                                        }
                                    },
                                    linting = {
                                        debounceTime = 250
                                    }
                                }
                            },
                            root_dir = require("lspconfig").util.root_pattern(
                                "settings.gradle.kts",
                                "settings.gradle",
                                "build.gradle.kts",
                                "build.gradle",
                                "pom.xml"
                            ),
                            flags = {
                                debounce_text_changes = 500,
                                allow_incremental_sync = true,
                            },
                            cmd = {
                                "kotlin-language-server",
                                "-J-Xmx4g",
                                "-J-Xms1g",
                                "-J-XX:+UseG1GC",
                                "-J-XX:+UseStringDeduplication",
                                "-J-Dkotlin.parallel.tasks.in.project=true",
                            }
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
                    vim.snippet.lsp_expand(args.body)
                end,
            },
            window = {
                completion = cmp.config.window.bordered({
                    winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None",
                    col_offset = -3,
                    side_padding = 1,
                    scrollbar = true,
                }),
                documentation = cmp.config.window.bordered({
                    winhighlight = "Normal:CmpDoc,FloatBorder:CmpDocBorder",
                    max_width = 80,
                    max_height = 20,
                }),
            },
            formatting = {
                fields = { 'kind', 'abbr', 'menu' }, -- Reordered for better readability
                format = lspkind.cmp_format({
                    mode = 'symbol_text',
                    maxwidth = 50, -- Prevent text from being too wide
                    ellipsis_char = '...',
                    before = function(entry, vim_item)
                        -- Add wrapping by truncating long text
                        vim_item.abbr = string.sub(vim_item.abbr, 1, 50)
                        return vim_item
                    end
                }),
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
                require("cmp").setup.buffer({
                    sources = {
                        { name = 'nvim_lsp' },              -- Add this line to enable BQLS!
                        { name = 'vim-dadbod-completion' }, -- Keep this if you use vim-dadbod
                        { name = 'luasnip' },               -- Optional: keep snippets working
                    }
                })
            end,
        })


        local default_pyright_mode = "openFilesOnly"
        local function toggle_pyright_workspace_mode()
            local bufnr = vim.api.nvim_get_current_buf()
            for _, client in pairs(vim.lsp.get_clients({ bufnr = bufnr })) do
                if client.name == "pyright" then
                    curr_mode = client.config.settings.python.analysis.diagnosticMode

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
