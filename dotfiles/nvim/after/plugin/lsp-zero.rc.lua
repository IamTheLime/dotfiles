local status, lspkind = pcall(require, "lspkind")
if (not status) then return end
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



-- DEFAULT KEYBINDS
--
--    K: Displays hover information about the symbol under the cursor
--    in a floating window. See :help vim.lsp.buf.hover().
--
--    gd: Jumps to the definition of the symbol under the cursor.
--    See :help vim.lsp.buf.definition().
--
--    gD: Jumps to the declaration of the symbol under the cursor.
--    Some servers don't implement this feature. See :help vim.lsp.buf.declaration().
--
--    gi: Lists all the implementations for the symbol under the cursor in the quickfix window.
--    See :help vim.lsp.buf.implementation().
--
--    go: Jumps to the definition of the type of the symbol under the cursor.
--    See :help vim.lsp.buf.type_definition().
--
--    gr: Lists all the references to the symbol under the cursor in the quickfix window.
--    See :help vim.lsp.buf.references().
--
--    <Ctrl-k>: Displays signature information about the symbol under the cursor in a floating window. See :help vim.lsp.buf.signature_help(). If a mapping already exists for this key this function is not bound.
--
--    <F2>: Renames all references to the symbol under the cursor.
--    See :help vim.lsp.buf.rename().
--
--
--    <F4>: Selects a code action available at the current cursor position. See :help vim.lsp.buf.code_action().
--
--    gl: Show diagnostics in a floating window. See :help vim.diagnostic.open_float().
--
--    [d: Move to the previous diagnostic in the current buffer. See :help vim.diagnostic.goto_prev().
--
--    ]d: Move to the next diagnostic. See :help vim.diagnostic.goto_next().


local status, lspzero = pcall(require, "lsp-zero")
if (not status) then
    return
end


local lsp = lspzero.preset({
    name = 'recommended',
    float_border = 'rounded',
    manage_nvim_cmp = { set_sources = 'recommended' },
    suggest_lsp_servers = true,
})

lsp.nvim_workspace()

lsp.on_attach(function(client, bufnr)
    vim.keymap.set({ 'n', 'x' }, 'gq', function()
        vim.lsp.buf.format({ async = true, timeout_ms = 1000 })
    end)
    lsp.default_keymaps({ buffer = bufnr })
    vim.keymap.set('n', 'gtr', '<cmd>Telescope lsp_references<cr>', { buffer = false })
end)
lsp.format_on_save({
    servers = {
        ['lua_ls'] = { 'lua' },
        ['rust_analyzer'] = { 'rust' },
    }
})


local status, lspconfig = pcall(require, "lspconfig")
if (not status) then
    return
end

lspconfig.pyright.setup({
    settings = {
        python = {
            analysis = {
                -- autoSearchPaths = true,
                -- diagnosticMode = "workspace",
                -- useLibraryCodeForTypes = true,
                extraPaths = { "app", "src", ".venv", ".local" },
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = 'workspace',
            },
        },
    },
    single_file_support = true,
    flags = {
        -- debounce_text_changes = 50,
        debounce_text_changes = 250,
    },
    on_attach = function(client, bufnr)
    end
})

-- This works, but forces every buffer to be formatted in full on save
-- lsp.on_attach(function(client, bufnr)
--  lsp.buffer_autoformat()
-- end)
lsp.set_sign_icons({
    error = '✘',
    warn = '▲',
    hint = '⚑',
    info = '»'
})


lsp.setup()

vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    update_in_insert = true,
    underline = false,
    severity_sort = false,
    float = true,
})



local status, null_ls = pcall(require, "null-ls")
if (not status) then
    return
end

local null_opts = lsp.build_options('null-ls', {})
-- Note: I might want toremove this in the future
null_ls.setup({
    on_attach = function(client, bufnr)
        -- print(vim.inspect(client), bufnr)
        -- local lsp_format_modifications = require("lsp-format-modifications")
        -- lsp_format_modifications.attach(client, bufnr, { format_on_save = true, async = true })
        null_opts.on_attach(client, bufnr)
    end,
    sources = {
        null_ls.builtins.formatting.autopep8,
        null_ls.builtins.formatting.black,
    },
})



local status, mason_null_ls = pcall(require, "mason-null-ls")
if (not status) then
    return
end
-- See mason-null-ls.nvim's documentation for more details:
-- https://github.com/jay-babu/mason-null-ls.nvim#setup
mason_null_ls.setup({
    ensure_installed = nil,
    automatic_installation = false, -- You can still set this to `true`
    automatic_setup = true,
})



local status, cmp = pcall(require, "cmp")
if (not status) then
    return
end
local cmp_action = lspzero.cmp_action()

require('luasnip.loaders.from_vscode').lazy_load()

cmp.setup({
    formatting = {
        -- changing the order of fields so the icon is the first
        fields = { 'menu', 'abbr', 'kind' },
        format = lspkind.cmp_format()
        -- here is where the change happens
        -- format = function(entry, item)
        --     local menu_icon = {
        --         nvim_lsp = 'λ',
        --         luasnip = '⋗',
        --         buffer = 'Ω',
        --         path = '🖫',
        --         nvim_lua = 'Π',
        --     }
        --
        --     item.menu = menu_icon[entry.source.name]
        --     return item
        -- end,
    },
    window = {
        completion = cmp.config.window.bordered(),
        documentation = cmp.config.window.bordered(),
    },
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body)
        end,
    },
    mapping = {
        ['<CR>'] = cmp.mapping.confirm({ select = true }),
        ['<Tab>'] = cmp_action.tab_complete(),
        ['<S-Tab>'] = cmp_action.select_prev_or_fallback(),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-u>'] = cmp.mapping.scroll_docs(4),
    }
})

local status, lsp_signature = pcall(require, "lsp_signature")
if (not status) then return end

lsp_signature.setup({
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
        border = "rounded"
    },
    always_trigger = true, -- sometime show signature on new line or in middle of parameter can be confusing, set it to false for #58
    toggle_key = '<M-s>',  -- toggle signature on and off in insert mode,  e.g. toggle_key = '<M-x>'
    timer_interval = 50
})
