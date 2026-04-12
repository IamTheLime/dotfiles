return {
    -- LSP Support
    'neovim/nvim-lspconfig',
    dependencies = {
        { 'williamboman/mason.nvim' },
        { 'williamboman/mason-lspconfig.nvim' },
        { 'saghen/blink.cmp' },
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
        -- Apply blink.cmp capabilities to all LSP servers via wildcard config
        vim.lsp.config("*", {
            capabilities = require("blink.cmp").get_lsp_capabilities(),
        })

        vim.api.nvim_create_autocmd('LspAttach', {
            desc = "LSP actions",
            callback = function(event)
                local opts = { buffer = event.buf }
                vim.keymap.set('n', 'K', function()
                    vim.lsp.buf.hover({ border = "single", title = " Hover ", title_pos = "center" })
                end, opts)
                vim.keymap.set({ 'n', 'i' }, '<C-s>', function()
                    vim.lsp.buf.signature_help({ border = "single", title = " Signature Help ", title_pos = "center" })
                end, opts)
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

        require('mason').setup({})

        vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
            pattern = "*.gitlab-ci*.{yml,yaml}",
            callback = function()
                vim.bo.filetype = "yaml.gitlab"
            end,
        })

        vim.fn.mkdir(vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), "p")

        -- =====================================================================
        -- Kotlin LSP Configuration
        -- =====================================================================
        -- kotlin-lsp (JetBrains) has known issues as of 2026-04:
        --
        -- 1. textEdit off-by-one: completion textEdits place cursor at wrong
        --    offset. Fixed in blink-cmp.lua transform_items by stripping
        --    textEdit and forcing plain label insertion.
        --
        -- 2. jar:/kls: URI navigation: Neovim can't natively open jar: or
        --    kls: URIs that kotlin-lsp returns for go-to-definition into
        --    compiled classes. Handled via custom gd/go keymaps, quickfix
        --    <CR> override, and BufReadCmd for kls: buffers below.
        -- =====================================================================
        local kotlin_lsp_storage = vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t")

        -- Native LSP server configurations (Neovim 0.12+)

        vim.lsp.config("kotlin_lsp", {
            cmd = {
                "env",
                "JAVA_TOOL_OPTIONS=-Xmx4g -XX:+UseG1GC -XX:SoftRefLRUPolicyMSPerMB=50 -XX:+UseStringDeduplication",
                "kotlin-lsp", "--stdio",
                "--system-path", kotlin_lsp_storage,
            },
            filetypes = { "kotlin" },
            init_options = {
                storageUri = "file://" .. kotlin_lsp_storage,
            },
            root_markers = {
                "settings.gradle.kts",
                "settings.gradle",
                "build.gradle.kts",
                "build.gradle",
                "pom.xml",
            },
        })

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

        require("mason-lspconfig").setup({
            automatic_enable = false,
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
