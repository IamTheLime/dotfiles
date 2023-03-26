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

local lsp = require('lsp-zero').preset({
  name = 'recommended',
  set_lsp_keymaps = true,
  manage_nvim_cmp = true,
  suggest_lsp_servers = true,
})

lsp.nvim_workspace()

lsp.on_attach(function(client, bufnr)
  vim.keymap.set({ 'n', 'x' }, 'gq', function()
    vim.lsp.buf.format({ async = false, timeout_ms = 10000 })
  end)
end)
lsp.format_on_save({
  servers = {
    ['lua_ls'] = { 'lua' },
    ['rust_analyzer'] = { 'rust' },
  }
})

-- This works, but forces every buffer to be formatted in full on save
-- lsp.on_attach(function(client, bufnr)
--  lsp.buffer_autoformat()
-- end)

lsp.setup()

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  update_in_insert = true,
  underline = false,
  severity_sort = false,
  float = true,
})



local null_ls = require("null-ls")
local null_opts = lsp.build_options('null-ls', {})
-- Note: I might want toremove this in the future
null_ls.setup({
  on_attach = function(client, bufnr)
    print(vim.inspect(client), bufnr)
    local lsp_format_modifications = require("lsp-format-modifications")
    lsp_format_modifications.attach(client, bufnr, { format_on_save = true })
    null_opts.on_attach(client, bufnr)
  end,
  sources = {
    null_ls.builtins.formatting.autopep8,
    null_ls.builtins.formatting.black,
  },
})

-- See mason-null-ls.nvim's documentation for more details:
-- https://github.com/jay-babu/mason-null-ls.nvim#setup
require('mason-null-ls').setup({
  ensure_installed = nil,
  automatic_installation = false, -- You can still set this to `true`
  automatic_setup = true,
})

-- Required when `automatic_setup` is true
require('mason-null-ls').setup_handlers()

local cmp = require('cmp')

cmp.setup({
  sources = {
    { name = 'nvim_lsp' },
  },
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
  })
})
