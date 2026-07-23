local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "TITLE | RESIZE"

-- Padding gives the content some breathing room inside the frame.
config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 8,
}

return config
