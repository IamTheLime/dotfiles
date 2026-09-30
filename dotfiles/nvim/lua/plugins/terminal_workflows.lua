-- terminal_workflows: mirrors LSP hover (K) into the app's sidebar and adds :TW.
-- Finds the client in the main checkout or in a git worktree under the
-- dotfiles (Claude's worktrees live in a hidden `.claude` folder, which a
-- `**` glob would skip), and stays inert when neither exists.
local function client_dir()
    local patterns = {
        "~/Documents/personal/dotfiles/terminal_workflows/clients/nvim",
        "~/Documents/personal/dotfiles/.claude/worktrees/*/terminal_workflows/clients/nvim",
        "~/Documents/personal/dotfiles/*/.claude/worktrees/*/terminal_workflows/clients/nvim",
        "~/Documents/personal/dotfiles/*/*/.claude/worktrees/*/terminal_workflows/clients/nvim",
    }
    for _, pattern in ipairs(patterns) do
        for _, dir in ipairs(vim.fn.glob(pattern, true, true)) do
            if vim.uv.fs_stat(dir .. "/lua/terminal_workflows/init.lua") then return dir end
        end
    end
    return nil
end

local dir = client_dir()
return {
    dir = dir or vim.fn.stdpath("data") .. "/terminal_workflows-missing",
    name = "terminal_workflows",
    cond = dir ~= nil,
    event = "LspAttach",
    cmd = "TW",
    opts = {},
}
