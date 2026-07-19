extends CanvasLayer

signal restart_requested
signal quit_requested

const UI_THEME := preload("res://scripts/ui_theme.gd")

var health_label: Label
var enemy_label: Label
var stamina_bar: ProgressBar
var stamina_value_label: Label
var controls_label: Label
var toast_label: Label
var terminal_panel: PanelContainer
var terminal_title: Label
var terminal_subtitle: Label
var restart_button: Button
var hurt_overlay: ColorRect
var _toast_tween: Tween
var _hurt_tween: Tween
var _stamina_tween: Tween

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	InputRouter.device_changed.connect(_on_device_changed)
	_on_device_changed(InputRouter.device_name(), InputRouter.last_joypad_id)

func set_health(current: int, maximum: int) -> void:
	if not is_instance_valid(health_label):
		return
	var hearts := ""
	for i in maximum:
		hearts += "♥ " if i < current else "♡ "
	health_label.text = hearts.strip_edges()

func set_stamina(current: float, maximum: float) -> void:
	if not is_instance_valid(stamina_bar):
		return
	var ratio := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	stamina_bar.value = ratio * 100.0
	stamina_value_label.text = "%d" % int(round(current))
	var color := Color("ff7a68") if ratio < 0.25 else Color("8de4dc")
	stamina_bar.modulate = color
	stamina_value_label.add_theme_color_override("font_color", color)

func set_enemy_count(current: int, total: int) -> void:
	if is_instance_valid(enemy_label):
		enemy_label.text = "守卫  %d / %d" % [current, total]

func show_toast(message: String, duration := 2.0) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = message
	toast_label.modulate.a = 0.0
	_toast_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.25)

func flash_hurt() -> void:
	if _hurt_tween and _hurt_tween.is_valid():
		_hurt_tween.kill()
	hurt_overlay.modulate.a = 0.5
	_hurt_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hurt_tween.tween_property(hurt_overlay, "modulate:a", 0.0, 0.28)

func flash_stamina() -> void:
	if not is_instance_valid(stamina_bar):
		return
	if _stamina_tween and _stamina_tween.is_valid():
		_stamina_tween.kill()
	stamina_bar.modulate = Color("ff453f")
	stamina_value_label.modulate = Color("ff453f")
	_stamina_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_stamina_tween.tween_property(stamina_bar, "modulate", Color("8de4dc"), 0.32)
	_stamina_tween.parallel().tween_property(stamina_value_label, "modulate", Color.WHITE, 0.32)

func show_terminal(won: bool) -> void:
	terminal_panel.visible = true
	terminal_title.text = "DAWN AWAITS" if won else "FALLEN"
	terminal_title.add_theme_color_override("font_color", Color("f3ca72") if won else Color("ff776f"))
	terminal_subtitle.text = "你穿过了暮色废墟" if won else ("从月光祭坛重新迎战" if RunState.has_shrine_checkpoint() else "小骑士倒下了")
	restart_button.text = "重新开始" if won or not RunState.has_shrine_checkpoint() else "从祭坛重试"
	restart_button.grab_focus()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI_THEME.create_theme()
	add_child(root)

	hurt_overlay = ColorRect.new()
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.color = Color(0.65, 0.04, 0.07, 0.33)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt_overlay.modulate.a = 0.0
	root.add_child(hurt_overlay)

	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(8, 8)
	status_panel.size = Vector2(226, 58)
	root.add_child(status_panel)
	var status := VBoxContainer.new()
	status.add_theme_constant_override("separation", 2)
	status_panel.add_child(status)
	var top_row := HBoxContainer.new()
	status.add_child(top_row)
	health_label = Label.new()
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_label.add_theme_color_override("font_color", Color("ffcf6b"))
	top_row.add_child(health_label)
	enemy_label = Label.new()
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(enemy_label)
	var stamina_row := HBoxContainer.new()
	stamina_row.add_theme_constant_override("separation", 4)
	status.add_child(stamina_row)
	var stamina_title := Label.new()
	stamina_title.text = "精力"
	stamina_title.custom_minimum_size.x = 31
	stamina_title.add_theme_font_size_override("font_size", 9)
	stamina_row.add_child(stamina_title)
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(139, 8)
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stamina_row.add_child(stamina_bar)
	stamina_value_label = Label.new()
	stamina_value_label.text = "100"
	stamina_value_label.custom_minimum_size.x = 28
	stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_value_label.add_theme_font_size_override("font_size", 8)
	stamina_row.add_child(stamina_value_label)

	var title := Label.new()
	title.text = "LITTLE KNIGHT"
	title.position = Vector2(480, 8)
	title.size = Vector2(150, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("f7e5bc"))
	root.add_child(title)
	controls_label = Label.new()
	controls_label.position = Vector2(238, 26)
	controls_label.size = Vector2(392, 38)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	controls_label.add_theme_font_size_override("font_size", 8)
	controls_label.add_theme_constant_override("line_spacing", -1)
	controls_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9, 0.92))
	root.add_child(controls_label)

	toast_label = Label.new()
	toast_label.position = Vector2(130, 70)
	toast_label.size = Vector2(380, 28)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color("fff0c9"))
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	terminal_panel = PanelContainer.new()
	terminal_panel.position = Vector2(175, 110)
	terminal_panel.size = Vector2(290, 142)
	terminal_panel.visible = false
	root.add_child(terminal_panel)
	var terminal_content := VBoxContainer.new()
	terminal_content.alignment = BoxContainer.ALIGNMENT_CENTER
	terminal_content.add_theme_constant_override("separation", 8)
	terminal_panel.add_child(terminal_content)
	terminal_title = Label.new()
	terminal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal_title.add_theme_font_size_override("font_size", 19)
	terminal_content.add_child(terminal_title)
	terminal_subtitle = Label.new()
	terminal_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal_content.add_child(terminal_subtitle)
	var terminal_buttons := HBoxContainer.new()
	terminal_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	terminal_buttons.add_theme_constant_override("separation", 8)
	terminal_content.add_child(terminal_buttons)
	restart_button = _make_button("重新开始")
	restart_button.pressed.connect(func(): restart_requested.emit())
	terminal_buttons.add_child(restart_button)
	var quit_button := _make_button("退出游戏")
	quit_button.pressed.connect(func(): quit_requested.emit())
	terminal_buttons.add_child(quit_button)

func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(96, 25)
	button.focus_entered.connect(func(): AudioManager.play_sfx(&"ui_focus", 0.02, -8.0))
	button.pressed.connect(func(): AudioManager.play_sfx(&"ui_confirm", 0.02, -5.0))
	return button

func _on_device_changed(_kind: StringName, _joypad_id: int) -> void:
	var move_prompt := "LS / D-PAD" if InputRouter.is_gamepad_active() else InputRouter.prompt_for(&"move_left")
	controls_label.text = "%s 移动  %s 跳跃  %s 轻击\n%s 重击  %s 防御  %s 闪避" % [
		move_prompt,
		InputRouter.prompt_for(&"jump"),
		InputRouter.prompt_for(&"attack"),
		InputRouter.prompt_for(&"heavy_attack"),
		InputRouter.prompt_for(&"guard"),
		InputRouter.prompt_for(&"dash"),
	]
