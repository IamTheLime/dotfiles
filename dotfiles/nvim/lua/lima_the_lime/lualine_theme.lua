local M = {}

-- Resolve links without creating missing highlight groups. Respect reversed
-- highlights too (common in Vim's built-in and light colorschemes).
local function highlight_color(groups, attribute, fallback)
    for _, group in ipairs(groups) do
        local hl = vim.api.nvim_get_hl(0, { name = group, link = false, create = false })
        local key = hl.reverse and (attribute == "fg" and "bg" or "fg") or attribute
        if hl[key] then
            return string.format("#%06x", hl[key])
        end
    end
    return fallback
end

local function rgb(color)
    return {
        tonumber(color:sub(2, 3), 16),
        tonumber(color:sub(4, 5), 16),
        tonumber(color:sub(6, 7), 16),
    }
end

-- Interpolate in sRGB, matching the website's color-mix(in srgb, ...).
local function mix(base, tint, amount)
    local a, b = rgb(base), rgb(tint)
    local result = {}
    for index = 1, 3 do
        result[index] = math.floor(a[index] + (b[index] - a[index]) * amount + 0.5)
    end
    return string.format("#%02x%02x%02x", unpack(result))
end

local function luminance(color)
    local channels = rgb(color)
    for index, value in ipairs(channels) do
        value = value / 255
        channels[index] = value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
    end
    return channels[1] * 0.2126 + channels[2] * 0.7152 + channels[3] * 0.0722
end

local function contrast(a, b)
    local x, y = luminance(a), luminance(b)
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
end

-- Keep text readable even when a theme uses unusually dark accent colours.
local function readable(background, preferred)
    if contrast(background, preferred) >= 4.5 then
        return preferred
    end
    return contrast(background, "#000000") > contrast(background, "#ffffff") and "#000000" or "#ffffff"
end

function M.build()
    local dark = vim.o.background == "dark"
    local fg = highlight_color({ "Normal", "StatusLine" }, "fg", dark and "#ffffff" or "#000000")
    local bg = highlight_color({ "Normal", "NormalNC", "NormalFloat" }, "bg", nil)
    -- Transparent themes omit Normal.bg. Their terminal palette is the closest
    -- available estimate of the terminal surface beneath Neovim.
    local terminal_bg = vim.g.terminal_color_0
    if type(terminal_bg) ~= "string" or not terminal_bg:match("^#%x%x%x%x%x%x$") then
        terminal_bg = dark and "#101010" or "#f0f0f0"
    end
    bg = bg or terminal_bg

    local accents = {
        normal = highlight_color({ "Function", "Directory", "Identifier" }, "fg", fg),
        insert = highlight_color({ "String", "MoreMsg" }, "fg", fg),
        visual = highlight_color({ "Keyword", "Statement", "Special" }, "fg", fg),
        replace = highlight_color({ "DiagnosticError", "ErrorMsg" }, "fg", fg),
        command = highlight_color({ "Number", "Constant", "Type" }, "fg", fg),
        terminal = highlight_color({ "DiagnosticInfo", "Special" }, "fg", fg),
    }
    local theme = {}
    local middle = mix(bg, fg, 0.04)
    for mode, accent in pairs(accents) do
        local shoulder = mix(bg, accent, 0.18)
        theme[mode] = {
            a = { fg = readable(accent, bg), bg = accent, gui = "bold" },
            b = { fg = readable(shoulder, fg), bg = shoulder },
            c = { fg = readable(middle, fg), bg = middle },
        }
    end
    local inactive_bg = mix(bg, fg, 0.02)
    local inactive_fg = readable(inactive_bg, mix(bg, fg, 0.60))
    theme.inactive = {
        a = { fg = inactive_fg, bg = inactive_bg },
        b = { fg = inactive_fg, bg = inactive_bg },
        c = { fg = inactive_fg, bg = inactive_bg },
    }
    return theme
end

return M
