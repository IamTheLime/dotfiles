return {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter", branch = "main" },
    init = function()
        vim.g.no_plugin_maps = true
    end,
    config = function()
        require("nvim-treesitter-textobjects").setup({
            select = {
                lookahead = true,
                selection_modes = {
                    ["@parameter.outer"] = "v", -- charwise
                    ["@function.outer"] = "V",  -- linewise
                    ["@class.outer"] = "<c-v>", -- blockwise
                },
                include_surrounding_whitespace = false,
            },
            move = {
                set_jumps = true,
            },
        })

        -- =====================
        -- TEXT OBJECT SELECTS
        -- =====================
        local select = require("nvim-treesitter-textobjects.select")

        -- Function text objects (your original af/if mappings, using am/im)
        vim.keymap.set({ "x", "o", "v" }, "af", function()
            select.select_textobject("@function.outer", "textobjects")
        end)
        vim.keymap.set({ "x", "o", "v" }, "if", function()
            select.select_textobject("@function.inner", "textobjects")
        end)

        -- Class text objects (your original ac mapping)
        vim.keymap.set({ "x", "o", "v" }, "ac", function()
            select.select_textobject("@class.outer", "textobjects")
        end)
        vim.keymap.set({ "x", "o" }, "ic", function()
            select.select_textobject("@class.inner", "textobjects")
        end)

        -- COMMENTED OUT: Additional select mappings you may want later
        -- -- Scope selection (selects the current local scope)
        -- vim.keymap.set({ "x", "o" }, "as", function()
        --     select.select_textobject("@local.scope", "locals")
        -- end)

        -- =====================
        -- SWAPS
        -- =====================
        -- COMMENTED OUT: Swap parameters - useful for reordering function arguments
        -- local swap = require("nvim-treesitter-textobjects.swap")
        -- -- Swap current parameter with next
        -- vim.keymap.set("n", "<leader>a", function()
        --     swap.swap_next("@parameter.inner")
        -- end)
        -- -- Swap current parameter with previous
        -- vim.keymap.set("n", "<leader>A", function()
        --     swap.swap_previous("@parameter.outer")
        -- end)

        -- =====================
        -- MOVEMENTS
        -- =====================
        -- COMMENTED OUT: Navigate between functions/classes - useful for jumping around code
        -- local move = require("nvim-treesitter-textobjects.move")
        --
        -- -- Go to next function start
        -- vim.keymap.set({ "n", "x", "o" }, "]m", function()
        --     move.goto_next_start("@function.outer", "textobjects")
        -- end)
        -- -- Go to next class start
        -- vim.keymap.set({ "n", "x", "o" }, "]]", function()
        --     move.goto_next_start("@class.outer", "textobjects")
        -- end)
        -- -- Go to next loop (inner or outer)
        -- vim.keymap.set({ "n", "x", "o" }, "]o", function()
        --     move.goto_next_start({ "@loop.inner", "@loop.outer" }, "textobjects")
        -- end)
        -- -- Go to next local scope
        -- vim.keymap.set({ "n", "x", "o" }, "]s", function()
        --     move.goto_next_start("@local.scope", "locals")
        -- end)
        -- -- Go to next fold
        -- vim.keymap.set({ "n", "x", "o" }, "]z", function()
        --     move.goto_next_start("@fold", "folds")
        -- end)
        -- -- Go to next function end
        -- vim.keymap.set({ "n", "x", "o" }, "]M", function()
        --     move.goto_next_end("@function.outer", "textobjects")
        -- end)
        -- -- Go to next class end
        -- vim.keymap.set({ "n", "x", "o" }, "][", function()
        --     move.goto_next_end("@class.outer", "textobjects")
        -- end)
        -- -- Go to previous function start
        -- vim.keymap.set({ "n", "x", "o" }, "[m", function()
        --     move.goto_previous_start("@function.outer", "textobjects")
        -- end)
        -- -- Go to previous class start
        -- vim.keymap.set({ "n", "x", "o" }, "[[", function()
        --     move.goto_previous_start("@class.outer", "textobjects")
        -- end)
        -- -- Go to previous function end
        -- vim.keymap.set({ "n", "x", "o" }, "[M", function()
        --     move.goto_previous_end("@function.outer", "textobjects")
        -- end)
        -- -- Go to previous class end
        -- vim.keymap.set({ "n", "x", "o" }, "[]", function()
        --     move.goto_previous_end("@class.outer", "textobjects")
        -- end)
        -- -- Go to nearest conditional (start or end, whichever is closer)
        -- vim.keymap.set({ "n", "x", "o" }, "]d", function()
        --     move.goto_next("@conditional.outer", "textobjects")
        -- end)
        -- vim.keymap.set({ "n", "x", "o" }, "[d", function()
        --     move.goto_previous("@conditional.outer", "textobjects")
        -- end)

        -- =====================
        -- REPEATABLE MOVEMENTS
        -- =====================
        -- COMMENTED OUT: Make movements repeatable with ; and ,
        -- local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")
        --
        -- -- Repeat last movement with ; (forward) and , (backward)
        -- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
        -- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)
        --
        -- -- Make builtin f, F, t, T also repeatable with ; and ,
        -- vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
        -- vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
        -- vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
        -- vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })
    end,
}
