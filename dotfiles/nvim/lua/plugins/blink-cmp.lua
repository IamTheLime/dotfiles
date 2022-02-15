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
                -- blink writes completions to vim's `.` register for
                -- dot-repeat by spinning up a temporary floating
                -- window, calling `vim.fn.complete()`, then queueing
                -- `<C-x><C-z>` via `nvim_feedkeys('in', false)`. That
                -- feedkeys runs on the next event tick (~7ms) and
                -- leaves the cursor one column to the left of where
                -- apply_text_edits put it — a deferred off-by-one
                -- that's especially visible when kotlin-lsp's
                -- command applyEdit also runs (the trace shows the
                -- cursor drifting from saved → saved-1 after handler).
                -- We don't use dot-repeat for LSP completions; turn
                -- it off to keep the cursor stable.
                dot_repeat = false,
                auto_brackets = {
                    enabled = true,
                    blocked_filetypes = { "kotlin" },
                },
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
                draw = {
                    -- icon | label | signature | source/module
                    columns = {
                        { 'kind_icon' },
                        { 'label' },
                        { 'label_detail' },
                        { 'label_description' },
                    },
                    components = {
                        -- Same as the default `label`, minus the appended
                        -- detail (we render that in its own column below).
                        label = {
                            width = { fill = true, max = 60 },
                            text = function(ctx) return ctx.label end,
                            highlight = function(ctx)
                                local highlights = {
                                    {
                                        0,
                                        #ctx.label,
                                        group = ctx.deprecated and 'BlinkCmpLabelDeprecated' or 'BlinkCmpLabel',
                                    },
                                }
                                if vim.list_contains(ctx.self.treesitter, ctx.source_id) and not ctx.deprecated then
                                    vim.list_extend(
                                        highlights,
                                        require('blink.cmp.completion.windows.render.treesitter').highlight(ctx)
                                    )
                                end
                                for _, idx in ipairs(ctx.label_matched_indices) do
                                    table.insert(highlights, { idx, idx + 1, group = 'BlinkCmpLabelMatch' })
                                end
                                return highlights
                            end,
                        },
                        -- Signature: `labelDetails.detail` when the server
                        -- sends it up front (gopls, rust-analyzer, kotlin-lsp),
                        -- otherwise `detail` from completionItem/resolve
                        -- (ts_ls/vtsls, pyright) — see the prefetch in config().
                        label_detail = {
                            width = { max = 50 },
                            ellipsis = true,
                            text = function(ctx)
                                if ctx.label_detail ~= '' then return ctx.label_detail end

                                local detail = ctx.item.detail

                                if type(detail) == 'string' and detail ~= '' then
                                    -- `detail` is often multi-line (tsserver appends
                                    -- "import Foo", type bodies, ...); the signature
                                    -- is the first line
                                    detail = detail:match('^[^\n]*')
                                else
                                    -- pyright sends no detail/labelDetails at all —
                                    -- the signature is the fenced code block at the
                                    -- top of `documentation`, often wrapped over
                                    -- several lines
                                    local doc = ctx.item.documentation
                                    local doc_text = type(doc) == 'table' and doc.value or doc
                                    detail = type(doc_text) == 'string' and doc_text:match('^```%w*\n(.-)\n?```')
                                end

                                if type(detail) ~= 'string' or detail == '' then return '' end
                                detail = detail:gsub('%s+', ' ')

                                -- Drop the part of the detail that repeats the
                                -- label, so we only show params/return type:
                                --   ts_ls:  "(alias) function foo(a: string): void"
                                --   lua_ls: "function vim.api.nvim_buf_set_lines(buffer: integer, ...)"
                                -- Try the whole label first, then just its leading
                                -- identifier (lua_ls labels carry untyped params).
                                local _, label_end = detail:find(ctx.item.label, 1, true)
                                if label_end == nil then
                                    local base = ctx.item.label:match('[%w_]+')
                                    if base then _, label_end = detail:find(base, 1, true) end
                                end
                                if label_end then detail = detail:sub(label_end + 1) end

                                -- tidy the joins left by collapsing a wrapped
                                -- signature onto one line
                                detail = detail:gsub('%(%s+', '('):gsub('%s+%)', ')'):gsub('%s+,', ',')

                                detail = vim.trim(detail)
                                -- nothing left but the kind ("interface Foo") — the
                                -- kind icon already says that
                                if detail == ctx.item.label then return '' end
                                return detail
                            end,
                            highlight = 'BlinkCmpLabelDetail',
                        },
                    },
                },
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
                        -- Note: the kotlin-lsp textEdit-stripping workaround
                        -- was removed 2026-06. kotlin-lsp ≥ v262.7569.0 uses a
                        -- clean command-based completion model (empty textEdit
                        -- + `jetbrains.kotlin.completion.apply` command that
                        -- blink runs on accept). Stripping/forcing insertText
                        -- now double-inserts and fights the server's applyEdit.
                        for _, item in ipairs(items) do
                            local boost = kind_scores[item.kind] or 0
                            -- Kwargs: pyright labels them as "param="
                            if (item.label or ""):match("=$") then
                                boost = boost + 10
                            end
                            item.score_offset = (item.score_offset or 0) + boost
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

        -- Signature prefetch.
        --
        -- Some servers (ts_ls/vtsls, pyright) only send the signature in
        -- `detail` on completionItem/resolve, which blink normally only
        -- requests for the *selected* item (for the docs window). So the
        -- `label_detail` column above would stay empty for them.
        --
        -- Resolve the top N visible items in the background and redraw the
        -- menu once they land. Resolution is cached per (source, item) by
        -- blink, so this costs one round trip per item per completion
        -- session, not per keystroke.
        local PREFETCH_COUNT = 20
        local prefetch_timer = vim.uv.new_timer()

        local function prefetch_details()
            local ok, menu = pcall(require, 'blink.cmp.completion.windows.menu')
            if not ok or not menu.win or not menu.win:is_open() then return end

            local context = menu.context
            if context == nil or menu.renderer == nil then return end

            local sources = require('blink.cmp.sources.lib')
            local items = menu.items or {}

            -- items still missing a signature
            local pending = {}
            for i = 1, math.min(#items, PREFETCH_COUNT) do
                local item = items[i]
                local has_detail = (type(item.labelDetails) == 'table' and item.labelDetails.detail)
                    or (type(item.detail) == 'string' and item.detail ~= '')
                    or item.documentation ~= nil
                if not has_detail then table.insert(pending, item) end
            end
            if #pending == 0 then return end

            local remaining, dirty = #pending, false

            local function finish()
                remaining = remaining - 1
                if remaining > 0 or not dirty then return end
                vim.schedule(function()
                    -- the menu may have closed or moved on to a new context
                    if not menu.win:is_open() or menu.context ~= context then return end
                    menu.renderer:draw(context, menu.win:get_buf(), menu.items)
                    menu.update_position()
                end)
            end

            for _, item in ipairs(pending) do
                sources.resolve(context, item):map(function(resolved)
                    if type(resolved) == 'table' then
                        -- write back onto the item the menu holds, so the
                        -- draw context picks it up on redraw
                        if item.detail == nil and resolved.detail ~= nil then
                            item.detail = resolved.detail
                            dirty = true
                        end
                        if item.labelDetails == nil and resolved.labelDetails ~= nil then
                            item.labelDetails = resolved.labelDetails
                            dirty = true
                        end
                        if item.documentation == nil and resolved.documentation ~= nil then
                            item.documentation = resolved.documentation
                            dirty = true
                        end
                    end
                    finish()
                end)
            end
        end

        vim.api.nvim_create_autocmd('User', {
            pattern = { 'BlinkCmpMenuOpen', 'BlinkCmpMenuPositionUpdate' },
            callback = function()
                prefetch_timer:stop()
                prefetch_timer:start(60, 0, vim.schedule_wrap(prefetch_details))
            end,
        })

        vim.api.nvim_create_autocmd('User', {
            pattern = 'BlinkCmpMenuClose',
            callback = function() prefetch_timer:stop() end,
        })
    end,
}
