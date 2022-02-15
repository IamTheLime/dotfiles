return {
    "obsidian-nvim/obsidian.nvim",
    lazy = true,
    cmd = { "Obsidian" },
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    init = function()
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function()
                vim.opt_local.conceallevel = 1
            end,
        })
    end,
    keys = {
        { "<Leader>on", "<cmd>Obsidian new<cr>",             desc = "New note" },
        { "<Leader>oo", "<cmd>Obsidian quick_switch<cr>",    desc = "Quick switch" },
        { "<Leader>os", "<cmd>Obsidian search<cr>",          desc = "Search" },
        { "<Leader>ot", "<cmd>Obsidian today<cr>",           desc = "Today's note" },
        { "<Leader>oy", "<cmd>Obsidian yesterday<cr>",       desc = "Yesterday's note" },
        { "<Leader>om", "<cmd>Obsidian tomorrow<cr>",        desc = "Tomorrow's note" },
        { "<Leader>od", "<cmd>Obsidian dailies<cr>",         desc = "Daily notes" },
        { "<Leader>ob", "<cmd>Obsidian backlinks<cr>",       desc = "Backlinks" },
        { "<Leader>ol", "<cmd>Obsidian links<cr>",           desc = "Links" },
        { "<Leader>of", "<cmd>Obsidian follow_link<cr>",     desc = "Follow link" },
        { "<Leader>oc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
        { "<Leader>op", "<cmd>Obsidian paste_img<cr>",       desc = "Paste image" },
        { "<Leader>or", "<cmd>Obsidian rename<cr>",          desc = "Rename note" },
        { "<Leader>ow", "<cmd>Obsidian workspace<cr>",       desc = "Switch workspace" },
        { "<Leader>oT", "<cmd>Obsidian template<cr>",        desc = "Insert template" },
        { "<Leader>og", "<cmd>Obsidian toc<cr>",             desc = "Table of contents" },
        { "<Leader>oe", "<cmd>Obsidian extract_note<cr>",    mode = "v",                desc = "Extract to new note" },
        { "<Leader>oL", "<cmd>Obsidian link<cr>",            mode = "v",                desc = "Link selection" },
    },
    ---@module 'obsidian'
    ---@type obsidian.config
    opts = {
        legacy_commands = false,
        workspaces = {
            {
                name = "personal",
                path = "~/Documents/obsidian/tiago_vault/",
            },
        },
        callbacks = {
            enter_note = function()
                local actions = require("obsidian.actions")
                vim.keymap.set("n", "<CR>", actions.smart_action, { buffer = true, desc = "Smart action" })
                vim.keymap.set("n", "]o", function() actions.nav_link("next") end, { buffer = true, desc = "Next link" })
                vim.keymap.set("n", "[o", function() actions.nav_link("prev") end, { buffer = true, desc = "Prev link" })
            end,
        },
    },
}
