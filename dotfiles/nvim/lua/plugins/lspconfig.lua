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
                vim.keymap.set('n', 'gd', function()
                    local client = vim.lsp.get_clients({ bufnr = event.buf })[1]
                    local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding)
                    vim.lsp.buf_request(event.buf, 'textDocument/definition', params, function(err, result, ctx)
                        if err or not result then return end
                        local locs = vim.islist(result) and result or { result }
                        if #locs == 0 then return end
                        local loc = locs[1]
                        local uri = loc.targetUri or loc.uri or ""
                        local range = loc.targetSelectionRange or loc.targetRange or loc.range or {}
                        local row = (range.start and range.start.line or 0) + 1
                        local col = range.start and range.start.character or 0

                        if uri:match("^jar:") then
                            local jar_path, inner_path = uri:match("^jar://(/[^!]+)!/(.+)$")
                            if jar_path and inner_path then
                                vim.cmd("edit zipfile://" .. jar_path .. "::" .. inner_path)
                                pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
                            end
                        elseif uri:match("^kls:") then
                            local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
                            if #clients == 0 then return end
                            clients[1]:request("kotlin/jarClassContents", { uri = uri }, function(_, req_result)
                                vim.schedule(function()
                                    if not (req_result and req_result.contents) then return end
                                    local lines = vim.split(req_result.contents, "\n")
                                    local bufnr = vim.fn.bufnr(uri)
                                    if bufnr == -1 then
                                        bufnr = vim.api.nvim_create_buf(true, false)
                                        vim.bo[bufnr].buftype = "nofile"
                                        vim.bo[bufnr].swapfile = false
                                        vim.api.nvim_buf_set_name(bufnr, uri)
                                    end
                                    vim.bo[bufnr].modifiable = true
                                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                                    vim.bo[bufnr].filetype = "kotlin"
                                    vim.bo[bufnr].modifiable = false
                                    vim.api.nvim_set_current_buf(bufnr)
                                    pcall(vim.api.nvim_win_set_cursor, 0, { math.min(row, #lines), col })
                                end)
                            end, ctx.bufnr)
                        else
                            local client = vim.lsp.get_client_by_id(ctx.client_id)
                            if client then
                                vim.lsp.util.show_document(loc, client.offset_encoding,
                                    { reuse_win = true, focus = true })
                            end
                        end
                    end)
                end, opts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', 'go', function()
                    local client = vim.lsp.get_clients({ bufnr = event.buf })[1]
                    local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding)
                    vim.lsp.buf_request(event.buf, 'textDocument/typeDefinition', params, function(err, result, ctx)
                        if err or not result then return end
                        local locs = vim.islist(result) and result or { result }
                        if #locs == 0 then return end
                        local loc = locs[1]
                        local uri = loc.targetUri or loc.uri or ""
                        local range = loc.targetSelectionRange or loc.targetRange or loc.range or {}
                        local row = (range.start and range.start.line or 0) + 1
                        local col = range.start and range.start.character or 0

                        if uri:match("^jar:") then
                            local jar_path, inner_path = uri:match("^jar://(/[^!]+)!/(.+)$")
                            if jar_path and inner_path then
                                vim.cmd("edit zipfile://" .. jar_path .. "::" .. inner_path)
                                pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
                            end
                        elseif uri:match("^kls:") then
                            local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
                            if #clients == 0 then return end
                            clients[1]:request("kotlin/jarClassContents", { uri = uri }, function(_, req_result)
                                vim.schedule(function()
                                    if not (req_result and req_result.contents) then return end
                                    local lines = vim.split(req_result.contents, "\n")
                                    local bufnr = vim.fn.bufnr(uri)
                                    if bufnr == -1 then
                                        bufnr = vim.api.nvim_create_buf(true, false)
                                        vim.bo[bufnr].buftype = "nofile"
                                        vim.bo[bufnr].swapfile = false
                                        vim.api.nvim_buf_set_name(bufnr, uri)
                                    end
                                    vim.bo[bufnr].modifiable = true
                                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                                    vim.bo[bufnr].filetype = "kotlin"
                                    vim.bo[bufnr].modifiable = false
                                    vim.api.nvim_set_current_buf(bufnr)
                                    pcall(vim.api.nvim_win_set_cursor, 0, { math.min(row, #lines), col })
                                end)
                            end, ctx.bufnr)
                        else
                            local client = vim.lsp.get_client_by_id(ctx.client_id)
                            if client then
                                vim.lsp.util.show_document(loc, client.offset_encoding,
                                    { reuse_win = true, focus = true })
                            end
                        end
                    end)
                end, opts)
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

        vim.fn.mkdir(vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), "p")

        vim.lsp.config("kotlin_lsp", {
            cmd = {
                "env",
                "JAVA_TOOL_OPTIONS=-Xmx4g -XX:+UseG1GC -XX:SoftRefLRUPolicyMSPerMB=50 -XX:+UseStringDeduplication",
                "kotlin-lsp", "--stdio",
                "--system-path", vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
            },
            filetypes = { "kotlin" },
            capabilities = capabilities,
            init_options = {
                storageUri = "file://" ..
                    vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
            },
            root_markers = {
                "settings.gradle.kts",
                "settings.gradle",
                "build.gradle.kts",
                "build.gradle",
                "pom.xml",
            },
            handlers = {
                ["textDocument/completion"] = function(err, result, ctx, config)
                    -- Strip textEdit from completion items to work around
                    -- kotlin-lsp off-by-one cursor placement bug
                    if result and result.items then
                        for _, item in ipairs(result.items) do
                            item.textEdit = nil
                        end
                    elseif result and not result.items then
                        for _, item in ipairs(result) do
                            item.textEdit = nil
                        end
                    end
                    return vim.lsp.handlers["textDocument/completion"](err, result, ctx, config)
                end,
            },
        })

        -- vim.lsp.config only registers config; enable is needed to auto-start on filetype
        vim.lsp.enable("kotlin_lsp")

        -- Handle jar: entries opened from the quickfix list (gr references, etc.)
        -- vim.lsp.buf.definition's inline handler bypasses vim.lsp.handlers in nvim 0.11,
        -- so gd is handled by the keymap above. But quickfix <CR> goes through a different
        -- path where neovim tries to open the jar: path literally (! causes parsing issues).
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "qf",
            callback = function()
                vim.keymap.set("n", "<CR>", function()
                    local items = vim.fn.getqflist()
                    local item = items[vim.fn.line(".")]
                    if not item then
                        vim.cmd("normal! \r")
                        return
                    end
                    local fname = item.filename
                        or (item.bufnr ~= 0 and vim.fn.bufname(item.bufnr) or "")
                    local jar_path, inner_path = fname:match("^jar://(/[^!]+)!/(.+)$")
                    if not jar_path then
                        vim.cmd("normal! \r")
                        return
                    end
                    vim.cmd("cclose")
                    vim.cmd("edit zipfile://" .. jar_path .. "::" .. inner_path)
                    if item.lnum and item.lnum > 0 then
                        pcall(vim.api.nvim_win_set_cursor, 0,
                            { item.lnum, math.max(0, (item.col or 1) - 1) })
                    end
                end, { buffer = true })
            end,
        })

        -- BufReadCmd fallback for kls: buffers (e.g. opened via Telescope references)
        vim.api.nvim_create_autocmd("BufReadCmd", {
            pattern = "kls:*",
            callback = function(ev)
                local buf = ev.buf
                local uri = ev.match
                vim.bo[buf].buftype = "nofile"
                vim.bo[buf].swapfile = false
                vim.bo[buf].modifiable = true

                local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
                if #clients == 0 then
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- kotlin_lsp client not available" })
                    vim.bo[buf].modifiable = false
                    return
                end
                local resp = clients[1]:request_sync("kotlin/jarClassContents", { uri = uri }, 5000)
                if resp and resp.result and resp.result.contents then
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(resp.result.contents, "\n"))
                else
                    local err = resp and resp.error and vim.inspect(resp.error) or "timeout or no response"
                    vim.notify("kotlin_lsp: failed to load " .. uri .. " (" .. err .. ")", vim.log.levels.WARN)
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- Error loading JAR: " .. err })
                end
                vim.bo[buf].filetype = "kotlin"
                vim.bo[buf].modifiable = false
            end,
        })

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
                    ["kotlin_lsp"] = function() end, -- configured via vim.lsp.config below
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
