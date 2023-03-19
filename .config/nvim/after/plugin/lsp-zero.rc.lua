local status, lsp = pcall(require, "lsp-zero")
if (not status) then return end

local lsp = require('lsp-zero').preset({
  name = 'recommended',
  set_lsp_keymaps = true,
  manage_nvim_cmp = true,
  suggest_lsp_servers = true,
})

lsp.setup_servers({'tsserver', 'eslint', 'pyright', 'rust_analyzer', 'sumneko_lua'})

-- (Optional) Configure lua language server for neovim
lsp.nvim_workspace()

lsp.setup()

vim.diagnostic.config({
    virtual_text = true,
    signs = true,
    update_in_insert = false,
    underline = true,
    severity_sort = false,
    float = true,
})
