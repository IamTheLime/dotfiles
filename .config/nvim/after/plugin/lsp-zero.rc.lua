
local lsp = require('lsp-zero').preset({
  name = 'recommended',
  set_lsp_keymaps = true,
  manage_nvim_cmp = true,
  suggest_lsp_servers = true,
})

lsp.nvim_workspace()
lsp.format_on_save({
  servers = {
    ['lua_ls'] = {'lua'},
    ['rust_analyzer'] = {'rust'},
  }
})

lsp.setup()

vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    update_in_insert = true,
    underline = true,
    severity_sort = false,
    float = true,
})



local null_ls = require("null-ls")
local null_opts = lsp.build_options('null-ls', {})
-- Note: I might want toremove this in the future 
null_ls.setup({
  on_attach = function(client, bufnr)
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

