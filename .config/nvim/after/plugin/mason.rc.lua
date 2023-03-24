local status, mason = pcall(require, "mason")
if (not status) then return end
local status2, lspconfig = pcall(require, "mason-lspconfig")
if (not status2) then return end

mason.setup({

})

lspconfig.setup {
  ensure_installed = { 
    "eslint_d",
    "black",
    "isort",
    "rust_analyzer@nightly", 
    "lua_ls", 
    "pyright",
    "tailwindcss" 
  },
}
