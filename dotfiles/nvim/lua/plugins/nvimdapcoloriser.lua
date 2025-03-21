-- return {
--   "chrisbra/Colorizer",
--   lazy = false,
--   init = function()
--     vim.g.colorizer_auto_filetype = "dap-repl"
--     vim.g.colorizer_disable_bufleave = 1
--
--     vim.api.nvim_create_autocmd("FileType", {
--       desc = "Force colorize on dap-repl",
--       pattern = "dap-repl",
--       group = vim.api.nvim_create_augroup("auto_colorize", { clear = true }),
--       callback = function() vim.cmd("ColorHighlight!") end,
--     })
--   end,
-- }

return {
    "m00qek/baleia.nvim",
    lazy=false,
    config = function()
        vim.g.baleia = require("baleia").setup({})
        vim.api.nvim_create_autocmd({ "FileType" }, {
            pattern = "dap-repl",
            callback = function()
                vim.g.baleia.automatically(vim.api.nvim_get_current_buf())
            end,
        })
    end
}
