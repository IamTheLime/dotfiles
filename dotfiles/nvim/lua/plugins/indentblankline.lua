return {
    'lukas-reineke/indent-blankline.nvim',
    main = "ibl",
    dependencies = { 'rose-pine/neovim' },
    config = function()
        local util = {}
        local function byte(value, offset)
            return bit.band(bit.rshift(value, offset), 0xFF)
        end
        local function rgb(color)
            color = vim.api.nvim_get_color_by_name(color)

            if color == -1 then
                color = vim.opt.background:get() == 'dark' and 000 or 255255255
            end

            return { byte(color, 16), byte(color, 8), byte(color, 0) }
        end

        local function parse_color(color)
            if color == nil then
                return print('invalid color')
            end

            color = color:lower()

            if not color:find('#') and color ~= 'none' then
                color = require('rose-pine.palette')[color]
                    or vim.api.nvim_get_color_by_name(color)
            end

            return color
        end

        ---@param fg string foreground color
        ---@param bg string background color
        ---@param alpha number number between 0 (background) and 1 (foreground)
        util.blend = function(fg, bg, alpha)
            local fg_rgb = rgb(parse_color(fg))
            local bg_rgb = rgb(parse_color(bg))

            local function blend_channel(i)
                local ret = (alpha * fg_rgb[i] + ((1 - alpha) * bg_rgb[i]))
                return math.floor(math.min(math.max(0, ret), 255) + 0.5)
            end

            return string.format(
                '#%02X%02X%02X',
                blend_channel(1),
                blend_channel(2),
                blend_channel(3)
            )
        end

        ---@param group string
        ---@param color table<string, any>
        util.highlight = function(group, color)
            local fg = color.fg and parse_color(color.fg) or 'none'

            if
                color.blend ~= nil
                and (color.blend >= 0 or color.blend <= 100)
            then
                fg = util.blend(fg, '#1A1B26', color.blend / 100)
            end

            local colours = {}


            if fg ~= nil then
                colours["fg"] = fg
            end

            colours["sp"] = "none"
            color = vim.tbl_extend('force', color, colours)
            vim.api.nvim_set_hl(0, group, color)
        end



        local h = util.highlight
        local b = util.blend
        vim.opt.list = true
        vim.opt.listchars = {
            -- eol = '↲',
            tab = '▸ ',
            trail = ' '
        }
        vim.opt.termguicolors = true
        local hooks = require "ibl.hooks"
        -- create the highlight groups in the highlight setup hook, so they are reset
        -- every time the colorscheme changes
        hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
            h('IndentBlanklineIndent1', { fg = "#E06C75", blend = 15 })
            h('IndentBlanklineIndent2', { fg = "#E5C07B", blend = 15 })
            h('IndentBlanklineIndent3', { fg = "#98C379", blend = 15 })
            h('IndentBlanklineIndent4', { fg = "#56B6C2", blend = 15 })
            h('IndentBlanklineIndent5', { fg = "#61AFEF", blend = 15 })
            h('IndentBlanklineIndent6', { fg = "#C678DD", blend = 15 })
        end)

        require("ibl").setup {
            indent = {
                highlight = {
                    "IndentBlanklineIndent1",
                    "IndentBlanklineIndent2",
                    "IndentBlanklineIndent3",
                    "IndentBlanklineIndent4",
                    "IndentBlanklineIndent5",
                    "IndentBlanklineIndent6",
                },
            },
            scope = { enabled = false },
        }
    end,
}
