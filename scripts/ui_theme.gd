extends RefCounted

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 10
	if ResourceLoader.exists("res://assets/fonts/fusion-pixel-12px-proportional.ttf"):
		theme.default_font = load("res://assets/fonts/fusion-pixel-12px-proportional.ttf")
	theme.set_color("font_color", "Label", Color("d8e5ef"))
	theme.set_color("font_shadow_color", "Label", Color(0.02, 0.03, 0.08, 0.9))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("normal", "Button", button_style(Color("17233d"), Color("536f8e")))
	theme.set_stylebox("hover", "Button", button_style(Color("243b5a"), Color("86c9c6")))
	theme.set_stylebox("pressed", "Button", button_style(Color("10182c"), Color("f1c56c")))
	theme.set_stylebox("focus", "Button", focus_style())
	theme.set_color("font_color", "Button", Color("d9e6ef"))
	theme.set_color("font_hover_color", "Button", Color("fff0bd"))
	theme.set_color("font_pressed_color", "Button", Color("f1c56c"))
	theme.set_constant("outline_size", "Button", 0)
	theme.set_stylebox("background", "ProgressBar", bar_background())
	theme.set_stylebox("fill", "ProgressBar", bar_fill())
	theme.set_color("font_color", "ProgressBar", Color.TRANSPARENT)
	return theme

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.11, 0.94)
	style.border_color = Color("526c8a")
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.shadow_color = Color(0.01, 0.015, 0.04, 0.65)
	style.shadow_size = 3
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

static func button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("f1c56c")
	style.set_border_width_all(2)
	style.expand_margin_left = 1
	style.expand_margin_right = 1
	style.expand_margin_top = 1
	style.expand_margin_bottom = 1
	return style

static func bar_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0c1324")
	style.border_color = Color("38506d")
	style.set_border_width_all(1)
	return style

static func bar_fill() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("75d6d0")
	style.border_color = Color("b7fff2")
	style.set_border_width_all(1)
	return style
