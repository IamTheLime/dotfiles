-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- hel:p provide clearer error messages
if wezterm.config_builder then
    config = wezterm.config_builder()
end

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
config.color_scheme = 'Tokyo Night'
config.window_decorations = "RESIZE"
config.font = wezterm.font('IosevkaTiago Nerd Font', { stretch = 'Normal', weight = 'Regular' })
-- and finally, return the configuration to wezterm
return config
