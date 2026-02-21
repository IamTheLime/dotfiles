-- lua/plugins/themes.lua

-- Set your active theme here
local active_theme = "rose-pine"

local themes = {
  {
	"rose-pine/neovim",
	name = "rose-pine",
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
  },
  {
    "folke/tokyonight.nvim",
    name = "tokyonight",
  },
  {
    "rebelot/kanagawa.nvim",
    name = "kanagawa",
  },
}

-- Apply lazy-loading logic based on active theme
for _, theme in ipairs(themes) do
  if theme.name == active_theme then
    theme.lazy = false
    theme.priority = 1000
    theme.config = function()
      vim.cmd("colorscheme " .. active_theme)
    end
  else
    theme.lazy = true
  end
end

return themes
