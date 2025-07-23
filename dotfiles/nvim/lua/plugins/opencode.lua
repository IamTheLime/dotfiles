return {
  "opencode-toggle",
  dir = vim.fn.stdpath('config') .. "/opencode-local",
  keys = {
    { "<leader>oa", "<cmd>OpencodeToggle<cr>", desc = "Toggle Opencode" },
  },
}
