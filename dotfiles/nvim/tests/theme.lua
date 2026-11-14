-- Run from any directory: nvim --headless -u NONE -l /path/to/tests/theme.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. "/themes/ember-grove")

local function equal(actual, expected, message)
    assert(vim.deep_equal(actual, expected), (message or "unexpected value")
        .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual))
end

local function hl(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
end

local function number(color)
    return tonumber(color:sub(2), 16)
end

local ember = require("ember-grove")
local palette = ember.palette
local adaptive = require("lima_the_lime.lualine_theme")
local specs = require("plugins.theme")
equal(specs[1].name, "ember-grove")
equal(specs[1].lazy, false)
specs[1].config()
equal(vim.g.colors_name, "ember-grove")
equal(vim.o.background, "dark")
for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "SignColumn", "NeoTreeNormal", "TelescopeNormal" }) do
    equal(hl(group).bg, nil, group .. " should be transparent")
end
equal(hl("Normal").fg, number(palette.foreground))
equal(hl("String").fg, number(palette.green))
equal(hl("Function").fg, number(palette.bright_blue))
equal(hl("@function").fg, hl("Function").fg)
equal(hl("@keyword").fg, hl("Keyword").fg)
equal(hl("@type").fg, hl("Type").fg)
equal(hl("@markup.strong").fg, number(palette.mint))
assert(hl("@markup.strong").fg ~= hl("Normal").fg, "Markdown bold needs colour contrast too")
equal(hl("@markup.heading").fg, number(palette.teal))
equal(hl("@variable").fg, number(palette.sage))
equal(hl("@variable.parameter").italic, true)
equal(hl("@lsp.type.variable").fg, hl("@variable").fg)
equal(hl("@lsp.type.property").fg, number(palette.foreground))
equal(hl("@lsp.typemod.variable.readonly").fg, hl("Constant").fg)
equal(hl("@lsp.typemod.property.readonly").bold, true)
assert(hl("@variable").fg ~= hl("Constant").fg, "variables and constants must differ")
for _, severity in ipairs({ "Error", "Warn", "Info", "Hint", "Ok" }) do
    equal(hl("DiagnosticUnderline" .. severity).sp, hl("Diagnostic" .. severity).fg)
end

local theme = adaptive.build()
for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
    for _, section in ipairs({ "a", "b", "c" }) do
        for _, attribute in ipairs({ "fg", "bg" }) do
            assert(theme[mode][section][attribute]:match("^#%x%x%x%x%x%x$"), "invalid lualine colour")
        end
    end
end
equal(theme.normal.a.bg, palette.bright_blue)
-- 18% copper over the green-black terminal background, rounded per channel.
equal(theme.normal.b.bg, "#2f2518", "lualine should interpolate section backgrounds")
assert(theme.normal.b.bg ~= theme.insert.b.bg, "mode accents should tint their sections")

ember.setup({ transparent = false })
vim.cmd("colorscheme ember-grove")
equal(hl("Normal").bg, number(palette.background))
ember.setup({ transparent = true })
vim.cmd("colorscheme ember-grove")
equal(hl("Normal").bg, nil)

-- Ghostty and embedded Neovim terminals must share exactly the same 16 colours.
local ghostty_path = root .. "/../ghostty/themes/Ember Grove"
local terminal_count = 0
for _, line in ipairs(vim.fn.readfile(ghostty_path)) do
    local index, color = line:match("^palette = (%d+)=(#%x+)$")
    if index then
        equal(vim.g["terminal_color_" .. index], color, "terminal palette mismatch")
        terminal_count = terminal_count + 1
    end
end
equal(terminal_count, 16)

-- Check real lualine integration: its own ColorScheme callback must re-run
-- the theme function, without custom callbacks or a second setup in theme.lua.
local lazy = vim.fn.stdpath("data") .. "/lazy/"
assert(vim.uv.fs_stat(lazy .. "lualine.nvim"), "install lualine before running these checks")
vim.opt.rtp:append(lazy .. "lualine.nvim")
if vim.uv.fs_stat(lazy .. "nvim-web-devicons") then
    vim.opt.rtp:append(lazy .. "nvim-web-devicons")
end
require("lualine").setup(require("plugins.lualine").opts)

local function check_lualine()
    local expected = adaptive.build()
    for mode, sections in pairs(expected) do
        for section, highlight in pairs(sections) do
            local actual = hl("lualine_" .. section .. "_" .. mode)
            equal(actual.bg, number(highlight.bg), "lualine didn't update: " .. section .. "/" .. mode)
            equal(actual.fg, number(highlight.fg))
        end
    end
end

check_lualine()
local initial_bg = hl("lualine_b_normal").bg
vim.cmd("colorscheme default")
check_lualine()
assert(hl("lualine_b_normal").bg ~= initial_bg, "lualine is stuck on Ember Grove")
vim.o.background = "light"
check_lualine()
assert(number(adaptive.build().normal.c.bg) > 0x808080, "light theme should have a light statusline")

-- Reversed, missing and transparent highlights should all produce valid colours.
vim.cmd("highlight clear")
vim.api.nvim_set_hl(0, "Normal", { fg = "#102030", bg = "#f0e0d0", reverse = true })
vim.api.nvim_set_hl(0, "Function", { fg = "#80a080" })
equal(adaptive.build().normal.c.bg, "#192836")
vim.api.nvim_set_hl(0, "Normal", {})
vim.api.nvim_set_hl(0, "NormalFloat", {})
vim.api.nvim_set_hl(0, "NormalNC", {})
vim.g.terminal_color_0 = "not-a-colour"
assert(adaptive.build().normal.c.bg:match("^#%x%x%x%x%x%x$"))

-- Exercise the other themes in the selector when they're installed locally.
for _, entry in ipairs({
    { "tokyonight", "tokyonight" },
    { "rose-pine", "rose-pine" },
    { "catppuccin", "catppuccin" },
    { "kanagawa", "kanagawa" },
}) do
    if vim.uv.fs_stat(lazy .. entry[1]) then
        vim.opt.rtp:prepend(lazy .. entry[1])
        vim.cmd("colorscheme " .. entry[2])
        check_lualine()
        print("lualine follows " .. entry[2])
    end
end
vim.cmd("colorscheme ember-grove")
check_lualine()
equal(hl("Normal").bg, nil)
print("Ember Grove: transparency, semantic colours, terminal palette and adaptive lualine OK")
