local status, treesitter = pcall(require, "nvim-treesitter.configs")
if (not status) then return end

treesitter.setup {
    ensure_installed = { "c", "lua", "vim", "typescript", "html", "markdown", "javascript", "json", "yaml", "rust",
        "vimdoc", "query", "tsx" },
    sync_install = false,
    auto_install = true,
    highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
    },
    auto_tag = {
        enable = true,
    }
}
