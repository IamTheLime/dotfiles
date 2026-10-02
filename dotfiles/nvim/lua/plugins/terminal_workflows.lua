local plugin_dir = vim.fn.expand("~/Documents/repos/BadTerm/main/clients/nvim")
if vim.fn.isdirectory(plugin_dir) == 0 then
    plugin_dir = vim.fn.expand("~/Documents/repos/BadTerm/clients/nvim")
end

return {
    dir = plugin_dir,
    name = "terminal_workflows",
    lazy = false,
    opts = {},
}
