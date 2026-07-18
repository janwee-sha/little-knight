extends CanvasLayer

signal pause_requested
signal resume_requested
signal restart_requested
signal quit_requested

const UI_THEME := preload("res://scripts/ui_theme.gd")

var _continue_button: Button
var _volume_slider: HSlider
var _volume_value: Label
var _restart_confirmation: ConfirmationDialog
var _quit_confirmation: ConfirmationDialog

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if visible:
			_request_resume()
		else:
			pause_requested.emit()
	elif visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _restart_confirmation.visible:
			_restart_confirmation.hide()
		elif _quit_confirmation.visible:
			_quit_confirmation.hide()
		else:
			_request_resume()

func open() -> void:
	visible = true
	_volume_slider.value = SettingsStore.sfx_volume * 100.0
	_continue_button.grab_focus()
	AudioManager.play_sfx(&"ui_confirm", 0.0, -6.0)

func close() -> void:
	visible = false

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI_THEME.create_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.04, 0.76)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(158, 47)
	panel.size = Vector2(324, 266)
	root.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	var title := Label.new()
	title.text = "游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("f1c56c"))
	content.add_child(title)
	_continue_button = _make_button("继续游戏")
	_continue_button.pressed.connect(_request_resume)
	content.add_child(_continue_button)
	var restart := _make_button("重新开始")
	restart.pressed.connect(func(): _restart_confirmation.popup_centered(Vector2i(250, 100)))
	content.add_child(restart)
	var audio_title := Label.new()
	audio_title.text = "音效音量"
	audio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(audio_title)
	var volume_row := HBoxContainer.new()
	volume_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(volume_row)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 5
	_volume_slider.custom_minimum_size = Vector2(190, 18)
	_volume_slider.value = SettingsStore.sfx_volume * 100.0
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(_volume_slider)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size.x = 35
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(_volume_value)
	_on_volume_changed(_volume_slider.value)
	var controls := Label.new()
	controls.text = "键鼠：A/D 移动  SPACE 跳跃  LMB 攻击  RMB 闪避\n手柄：摇杆/十字键移动  南键跳跃  西键攻击  东键闪避"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.custom_minimum_size = Vector2(290, 34)
	controls.add_theme_font_size_override("font_size", 9)
	content.add_child(controls)
	var quit := _make_button("退出游戏")
	quit.pressed.connect(func(): _quit_confirmation.popup_centered(Vector2i(250, 100)))
	content.add_child(quit)

	_restart_confirmation = ConfirmationDialog.new()
	_restart_confirmation.title = "重新开始"
	_restart_confirmation.dialog_text = "当前进度会丢失，确定重新开始吗？"
	_restart_confirmation.ok_button_text = "重新开始"
	_restart_confirmation.cancel_button_text = "取消"
	_restart_confirmation.confirmed.connect(func(): restart_requested.emit())
	root.add_child(_restart_confirmation)
	_quit_confirmation = ConfirmationDialog.new()
	_quit_confirmation.title = "退出游戏"
	_quit_confirmation.dialog_text = "确定退出 Little Knight 吗？"
	_quit_confirmation.ok_button_text = "退出"
	_quit_confirmation.cancel_button_text = "取消"
	_quit_confirmation.confirmed.connect(func(): quit_requested.emit())
	root.add_child(_quit_confirmation)

func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(210, 25)
	button.focus_entered.connect(func(): AudioManager.play_sfx(&"ui_focus", 0.02, -8.0))
	button.pressed.connect(func(): AudioManager.play_sfx(&"ui_confirm", 0.02, -5.0))
	return button

func _request_resume() -> void:
	AudioManager.play_sfx(&"ui_back", 0.02, -6.0)
	resume_requested.emit()

func _on_volume_changed(value: float) -> void:
	_volume_value.text = "%d%%" % int(value)
	SettingsStore.set_sfx_volume(value / 100.0)
