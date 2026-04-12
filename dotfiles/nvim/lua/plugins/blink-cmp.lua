return {
    'saghen/blink.cmp',
    version = '1.*',
    dependencies = {
        { 'rafamadriz/friendly-snippets' },
    },
    opts = {
        keymap = {
            preset = 'none',
            ['<CR>'] = { 'accept', 'fallback' },
            ['<C-Space>'] = { 'show', 'show_documentation', 'hide_documentation' },
            ['<C-e>'] = { 'hide', 'fallback' },
            ['<C-d>'] = { 'scroll_documentation_down', 'fallback' },
            ['<C-u>'] = { 'scroll_documentation_up', 'fallback' },
            ['<Up>'] = { 'select_prev', 'fallback' },
            ['<Down>'] = { 'select_next', 'fallback' },
            ['<C-p>'] = { 'select_prev', 'fallback' },
            ['<C-n>'] = { 'select_next', 'fallback' },
            ['<Tab>'] = { 'snippet_forward', 'fallback' },
            ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
        },
        appearance = {
            nerd_font_variant = 'mono',
        },
        completion = {
            accept = {
                auto_brackets = { enabled = true },
            },
            list = {
                selection = {
                    preselect = false,
                    auto_insert = false,
                },
            },
            menu = {
                border = 'single',
                scrollbar = true,
                winhighlight = 'Normal:Pmenu,FloatBorder:Pmenu,CursorLine:PmenuSel,Search:None',
            },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 150,
                window = {
                    border = 'single',
                    winhighlight = 'Normal:CmpDoc,FloatBorder:CmpDocBorder',
                },
            },
        },
        snippets = {
            preset = 'default',
        },
        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer' },
            per_filetype = {
                sql = { 'dadbod', 'lsp', 'path', 'buffer' },
                mysql = { 'dadbod', 'lsp', 'path', 'buffer' },
                plsql = { 'dadbod', 'lsp', 'path', 'buffer' },
            },
            providers = {
                lsp = {
                    -- Boost variables/constants, demote keywords/snippets
                    -- CompletionItemKind: 2=Method 3=Function 4=Constructor 5=Field
                    -- 6=Variable 7=Class 10=Property 13=Enum 14=Keyword 15=Snippet
                    -- 20=EnumMember 21=Constant 22=Struct
                    transform_items = function(ctx, items)
                        local kind_scores = {
                            [6]  = 8,  -- Variable
                            [21] = 6,  -- Constant
                            [20] = 6,  -- EnumMember
                            [5]  = 4,  -- Field
                            [10] = 4,  -- Property
                            [12] = 2,  -- Value
                            [22] = 2,  -- Struct
                            [13] = 2,  -- Enum
                            [14] = -4, -- Keyword
                            [15] = -6, -- Snippet
                            [1]  = -6, -- Text
                        }
                        local is_kotlin = vim.bo[ctx.bufnr].filetype == "kotlin"
                        for _, item in ipairs(items) do
                            local boost = kind_scores[item.kind] or 0
                            -- Kwargs: pyright labels them as "param="
                            if (item.label or ""):match("=$") then
                                boost = boost + 10
                            end
                            item.score_offset = (item.score_offset or 0) + boost

                            -- kotlin-lsp workaround: strip broken textEdits and
                            -- force plain label insertion to avoid off-by-one cursor
                            if is_kotlin then
                                item.textEdit = nil
                                item.additionalTextEdits = nil
                                item.command = nil
                                item.insertText = item.label
                                item.insertTextFormat = 1
                            end
                        end
                        return items
                    end,
                },
                dadbod = {
                    name = 'Dadbod',
                    module = 'vim_dadbod_completion.blink',
                },
            },
        },
        fuzzy = {
            implementation = 'prefer_rust_with_warning',
        },
    },
    opts_extend = { 'sources.default' },
    config = function(_, opts)
        require('blink.cmp').setup(opts)

        -- Add "Auto-Complete" title to the blink completion menu window
        vim.api.nvim_create_autocmd('User', {
            pattern = 'BlinkCmpMenuOpen',
            callback = function()
                local ok, menu = pcall(require, 'blink.cmp.completion.windows.menu')
                if ok and menu.win and menu.win:is_open() then
                    pcall(vim.api.nvim_win_set_config, menu.win:get_win(), {
                        title = " Auto-Complete ",
                        title_pos = "center",
                    })
                end
            end,
        })
    end,
}
