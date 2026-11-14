-- The Aether/Omarchy palette used by the SDL examples website.
-- Kept local so this colorscheme also works away from an Omarchy desktop.
local M = {}

M.palette = {
    background = "#0a1109",
    dark_background = "#080d07",
    darker_background = "#050905",
    lighter_background = "#232922",
    foreground = "#ffd872",
    dark_foreground = "#bfa256",
    light_foreground = "#ffde87",
    bright_foreground = "#ffe295",
    accent = "#b56e52",
    muted = "#656a64",
    red = "#c18c5e",
    green = "#edbd70",
    yellow = "#ffe88e",
    blue = "#b56e52",
    magenta = "#eb9866",
    cyan = "#ffd766",
    orange = "#ca9d76",
    brown = "#795e47",
    bright_red = "#e19e63",
    bright_green = "#ffd168",
    bright_yellow = "#ffe06a",
    bright_blue = "#d67e5b",
    bright_magenta = "#ffa764",
    bright_cyan = "#ffe954",
    -- OpenCode Matrix's muted text green: one quiet counterpoint to the gold.
    sage = "#8ca391",
    mint = "#a3d9b1",
    teal = "#7fcbbf",
}

local transparent = true

function M.setup(opts)
    transparent = (opts or {}).transparent ~= false
end

function M.load()
    vim.o.background = "dark"
    vim.o.termguicolors = true
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
    end
    vim.g.colors_name = "ember-grove"

    local p = M.palette
    local bg = transparent and "NONE" or p.background
    local highlights = {
        Normal = { fg = p.foreground, bg = bg },
        NormalNC = { fg = p.foreground, bg = bg },
        NormalFloat = { fg = p.foreground, bg = bg },
        FloatBorder = { fg = p.accent, bg = bg },
        FloatTitle = { fg = p.bright_foreground, bold = true },
        ColorColumn = { bg = p.lighter_background },
        CursorLine = { bg = p.lighter_background },
        CursorColumn = { link = "CursorLine" },
        CursorLineNr = { fg = p.bright_foreground, bold = true },
        LineNr = { fg = p.muted },
        SignColumn = { bg = bg },
        FoldColumn = { fg = p.muted, bg = bg },
        Folded = { fg = p.dark_foreground, bg = p.lighter_background },
        EndOfBuffer = { fg = p.lighter_background },
        NonText = { fg = p.muted },
        Whitespace = { fg = p.lighter_background },
        SpecialKey = { fg = p.muted },
        Conceal = { fg = p.dark_foreground },
        Cursor = { fg = p.background, bg = p.bright_foreground },
        lCursor = { link = "Cursor" },
        TermCursor = { link = "Cursor" },
        Visual = { bg = p.lighter_background },
        VisualNOS = { link = "Visual" },
        Search = { fg = p.background, bg = p.green },
        IncSearch = { fg = p.background, bg = p.magenta },
        CurSearch = { link = "IncSearch" },
        Substitute = { link = "IncSearch" },
        MatchParen = { fg = p.bright_cyan, bold = true, underline = true },
        Pmenu = { fg = p.foreground, bg = p.dark_background },
        PmenuSel = { fg = p.background, bg = p.green, bold = true },
        PmenuSbar = { bg = p.lighter_background },
        PmenuThumb = { bg = p.accent },
        PmenuMatch = { fg = p.bright_magenta, bold = true },
        PmenuMatchSel = { fg = p.background, bold = true },
        StatusLine = { fg = p.foreground, bg = p.lighter_background },
        StatusLineNC = { fg = p.dark_foreground, bg = p.dark_background },
        WinSeparator = { fg = p.brown, bg = bg },
        TabLine = { fg = p.dark_foreground, bg = p.dark_background },
        TabLineFill = { bg = bg },
        TabLineSel = { fg = p.background, bg = p.green, bold = true },
        WinBar = { fg = p.foreground, bg = bg },
        WinBarNC = { fg = p.dark_foreground, bg = bg },
        Title = { fg = p.bright_foreground, bold = true },
        Directory = { fg = p.green },
        Question = { fg = p.green },
        MoreMsg = { fg = p.green },
        ModeMsg = { fg = p.dark_foreground },
        ErrorMsg = { fg = p.bright_red, bold = true },
        WarningMsg = { fg = p.yellow },
        WildMenu = { link = "PmenuSel" },
        QuickFixLine = { bg = p.lighter_background, bold = true },
        Comment = { fg = p.muted, italic = true },
        Constant = { fg = p.cyan, bold = true },
        String = { fg = p.green },
        Character = { link = "String" },
        Number = { fg = p.cyan },
        Boolean = { fg = p.bright_magenta },
        Float = { link = "Number" },
        Identifier = { fg = p.sage },
        Function = { fg = p.bright_blue },
        Statement = { fg = p.magenta },
        Operator = { fg = p.dark_foreground },
        Keyword = { fg = p.magenta },
        PreProc = { fg = p.magenta },
        Type = { fg = p.yellow },
        Special = { fg = p.orange },
        Delimiter = { fg = p.dark_foreground },
        Underlined = { fg = p.cyan, underline = true },
        Ignore = { fg = p.muted },
        Error = { fg = p.bright_red, undercurl = true, sp = p.bright_red },
        Todo = { fg = p.background, bg = p.yellow, bold = true },
        Added = { fg = p.green },
        Changed = { fg = p.yellow },
        Removed = { fg = p.red },
        -- Diff backgrounds stay in the green-black family, never blue/purple.
        DiffAdd = { fg = p.green, bg = p.lighter_background },
        DiffChange = { bg = p.lighter_background },
        DiffDelete = { fg = p.red, bg = p.dark_background },
        DiffText = { fg = p.background, bg = p.dark_foreground, bold = true },
        DiagnosticError = { fg = p.bright_red },
        DiagnosticWarn = { fg = p.yellow },
        DiagnosticInfo = { fg = p.cyan },
        DiagnosticHint = { fg = p.dark_foreground },
        DiagnosticOk = { fg = p.green },
        DiagnosticUnnecessary = { fg = p.muted },
        DiagnosticDeprecated = { strikethrough = true, sp = p.red },
        LspReferenceText = { bg = p.lighter_background },
        LspReferenceRead = { link = "LspReferenceText" },
        LspReferenceWrite = { bg = p.lighter_background, underline = true },
        LspSignatureActiveParameter = { fg = p.bright_magenta, bold = true },
        LspInlayHint = { fg = p.muted },
        ["@variable"] = { fg = p.sage },
        ["@variable.builtin"] = { fg = p.orange },
        ["@variable.parameter"] = { fg = p.sage, italic = true },
        ["@variable.member"] = { fg = p.foreground },
        ["@constant.builtin"] = { link = "Boolean" },
        ["@module"] = { fg = p.yellow },
        ["@property"] = { link = "@variable.member" },
        ["@punctuation.delimiter"] = { link = "Delimiter" },
        ["@punctuation.bracket"] = { link = "Delimiter" },
        ["@punctuation.special"] = { fg = p.magenta },
        ["@string.escape"] = { fg = p.bright_magenta },
        ["@string.special.url"] = { link = "Underlined" },
        ["@markup.heading"] = { fg = p.teal, bold = true },
        ["@markup.strong"] = { fg = p.mint, bold = true },
        ["@markup.italic"] = { fg = p.bright_magenta, italic = true },
        ["@markup.strikethrough"] = { strikethrough = true },
        ["@markup.raw"] = { fg = p.green },
        ["@markup.link"] = { fg = p.teal },
        ["@markup.link.url"] = { fg = p.teal, underline = true },
        ["@markup.list"] = { fg = p.magenta },
        ["@tag"] = { fg = p.magenta },
        ["@tag.attribute"] = { fg = p.green },
        ["@tag.delimiter"] = { link = "Delimiter" },
        -- Semantic tokens inherit syntax colours rather than repainting them.
        ["@lsp.type.variable"] = { link = "@variable" },
        ["@lsp.type.parameter"] = { link = "@variable.parameter" },
        ["@lsp.type.property"] = { link = "@property" },
        ["@lsp.type.enumMember"] = { link = "Constant" },
        -- Immutable identifiers are constants, not ordinary green variables.
        -- Keep these type-specific so readonly functions/types aren't recoloured.
        ["@lsp.typemod.variable.readonly"] = { link = "Constant" },
        ["@lsp.typemod.property.readonly"] = { link = "Constant" },
        GitSignsAdd = { fg = p.green },
        GitSignsChange = { fg = p.yellow },
        GitSignsDelete = { fg = p.red },
        NeoTreeNormal = { link = "Normal" },
        NeoTreeNormalNC = { link = "NormalNC" },
        NeoTreeEndOfBuffer = { link = "EndOfBuffer" },
        NeoTreeWinSeparator = { link = "WinSeparator" },
        NeoTreeDirectoryName = { link = "Directory" },
        NeoTreeDirectoryIcon = { fg = p.accent },
        NeoTreeRootName = { fg = p.bright_foreground, bold = true },
        NeoTreeGitIgnored = { fg = p.brown, italic = true },
        TelescopeNormal = { link = "NormalFloat" },
        TelescopeBorder = { link = "FloatBorder" },
        TelescopeTitle = { link = "Title" },
        TelescopeSelection = { bg = p.lighter_background, bold = true },
        TelescopeMatching = { fg = p.bright_magenta, bold = true },
        BlinkCmpMenu = { link = "Pmenu" },
        BlinkCmpMenuBorder = { link = "FloatBorder" },
        BlinkCmpMenuSelection = { link = "PmenuSel" },
        BlinkCmpLabelMatch = { link = "PmenuMatch" },
        BlinkCmpDoc = { link = "NormalFloat" },
        BlinkCmpDocBorder = { link = "FloatBorder" },
        SnacksNormal = { link = "NormalFloat" },
        SnacksNormalNC = { link = "NormalNC" },
        SnacksWinBar = { link = "WinBar" },
        SnacksPickerBorder = { link = "FloatBorder" },
        SnacksPickerMatch = { link = "TelescopeMatching" },
    }

    for _, severity in ipairs({ "Error", "Warn", "Info", "Hint", "Ok" }) do
        local color = highlights["Diagnostic" .. severity].fg
        highlights["DiagnosticUnderline" .. severity] = { undercurl = true, sp = color }
        highlights["DiagnosticVirtualText" .. severity] = { fg = color }
        highlights["DiagnosticFloating" .. severity] = { fg = color, bg = bg }
        highlights["DiagnosticSign" .. severity] = { fg = color, bg = bg }
    end
    for name, highlight in pairs(highlights) do
        vim.api.nvim_set_hl(0, name, highlight)
    end

    local terminal = {
        p.background, p.red, p.green, p.yellow, p.blue, p.magenta, p.cyan, p.foreground,
        p.muted, p.bright_red, p.bright_green, p.bright_yellow,
        p.bright_blue, p.bright_magenta, p.bright_cyan, p.bright_foreground,
    }
    for index, color in ipairs(terminal) do
        vim.g["terminal_color_" .. (index - 1)] = color
    end
end

return M
