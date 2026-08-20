return {
    'dmtrKovalenko/fff.nvim',
    build = function()
        -- this will download prebuild binary or try to use existing rustup toolchain to build from source
        -- (if you are using lazy you can use gb for rebuilding a plugin if needed)
        require("fff.download").download_or_build_binary()
    end,
    -- if you are using nixos
    -- build = "nix run .#release",
    opts = {                      -- (optional)
        prompt_vim_mode = true,   -- <Esc> goes to normal mode in the prompt, second <Esc> closes
        prompt = 'INSERT 🦆 ',    -- leading word is swapped to NORMAL/INSERT/VISUAL by the mode hook below
        debug = {
            enabled = true,       -- we expect your collaboration at least during the beta
            show_scores = true,   -- to help us optimize the scoring system, feel free to share your scores!
        },
    },
    init = function()
        -- fff parses the query as everything after #config.prompt bytes, so the
        -- mode marker must keep a constant byte length: NORMAL/INSERT/VISUAL are
        -- 6 bytes each, and we mutate the live state prompt, the buffer text and
        -- a highlight extmark together
        local ns = vim.api.nvim_create_namespace('fff_mode_prompt')
        local mode_words = {
            n = { 'NORMAL', 'FffModeNormal' },
            i = { 'INSERT', 'FffModeInsert' },
            v = { 'VISUAL', 'FffModeVisual' },
            V = { 'VISUAL', 'FffModeVisual' },
            ['\22'] = { 'VISUAL', 'FffModeVisual' },
        }
        vim.api.nvim_set_hl(0, 'FffModeNormal', { link = 'Function', default = true })
        vim.api.nvim_set_hl(0, 'FffModeInsert', { link = 'String', default = true })
        vim.api.nvim_set_hl(0, 'FffModeVisual', { link = 'Statement', default = true })
        local function sync_prompt_mode(buf, mode)
            local st = require('fff.picker_ui.picker_ui_state').state
            if not (st.active and st.input_buf == buf and st.config and st.config.prompt) then return end
            local entry = mode_words[mode:sub(1, 1)]
            if not entry then return end
            local word, hl = entry[1], entry[2]
            local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
            if #line < #word then return end
            if st.config.prompt:sub(1, #word) ~= word then
                st.config.prompt = word .. st.config.prompt:sub(#word + 1)
                vim.fn.prompt_setprompt(buf, st.config.prompt)
                vim.api.nvim_buf_set_text(buf, 0, 0, 0, #word, { word })
            end
            vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
                id = 1,
                end_col = #word,
                hl_group = hl,
                priority = 200,
            })
        end
        vim.api.nvim_create_autocmd('FileType', {
            pattern = 'fff_input',
            callback = function(ev)
                vim.api.nvim_create_autocmd('ModeChanged', {
                    buffer = ev.buf,
                    callback = function() sync_prompt_mode(ev.buf, vim.v.event.new_mode) end,
                })
                -- prompt buffers only protect the prompt in insert mode; normal
                -- mode operators (dd, d0, db, visual d) can eat it, so rebuild
                -- the prefix around whatever query text survived the edit
                vim.api.nvim_create_autocmd('TextChanged', {
                    buffer = ev.buf,
                    callback = function()
                        local st = require('fff.picker_ui.picker_ui_state').state
                        if not (st.active and st.input_buf == ev.buf and st.config and st.config.prompt) then return end
                        local prompt = st.config.prompt
                        local line = vim.api.nvim_buf_get_lines(ev.buf, 0, 1, false)[1] or ''
                        if line:sub(1, #prompt) == prompt then return end
                        local query = line
                        local duck_end = line:find('🦆 ', 1, true)
                        if duck_end then query = line:sub(duck_end + #'🦆 ') end
                        vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, { prompt .. query })
                        pcall(vim.api.nvim_win_set_cursor, 0, { 1, #prompt + #query })
                        sync_prompt_mode(ev.buf, vim.api.nvim_get_mode().mode)
                    end,
                })
                -- resume() schedules a stopinsert after restoring the query;
                -- defer past it so every open lands in insert mode
                vim.defer_fn(function()
                    if vim.api.nvim_get_current_buf() == ev.buf then vim.cmd('startinsert!') end
                    sync_prompt_mode(ev.buf, vim.api.nvim_get_mode().mode)
                end, 25)
            end,
        })
    end,
    -- No need to lazy-load with lazy.nvim.
    -- This plugin initializes itself lazily.
    lazy = false,
    keys = {
        {
            ";f", -- try it if you didn't it is a banger keybinding for a picker
            function() require('fff').find_files() end,
            desc = 'FFFind files',
        },
        {
            ";r",
            function() require('fff').live_grep({ resume = true, title = "🕵️‍♂️ Please find a file", grep = { modes = { "fuzzy", "plain", "regex" } } }) end,
            desc = 'FFF grep in files',
        },
        {
            ";sw",
            function() require('fff').live_grep_under_cursor() end,
            mode = { 'n', 'x' },
            desc = 'FFF grep selected file',
        }
    }
}
