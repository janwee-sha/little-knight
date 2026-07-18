extends Node

signal device_changed(kind: StringName, joypad_id: int)

enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

var device_kind := DeviceKind.KEYBOARD_MOUSE
var last_joypad_id := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_actions()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_set_device(DeviceKind.GAMEPAD, event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.35:
		_set_device(DeviceKind.GAMEPAD, event.device)
	elif event is InputEventKey and event.pressed:
		_set_device(DeviceKind.KEYBOARD_MOUSE, -1)
	elif event is InputEventMouseButton and event.pressed:
		_set_device(DeviceKind.KEYBOARD_MOUSE, -1)
	elif event is InputEventMouseMotion and event.relative.length_squared() >= 4.0:
		_set_device(DeviceKind.KEYBOARD_MOUSE, -1)

func _set_device(next_kind: DeviceKind, joypad_id: int) -> void:
	var changed := device_kind != next_kind or (next_kind == DeviceKind.GAMEPAD and last_joypad_id != joypad_id)
	if next_kind == DeviceKind.GAMEPAD:
		last_joypad_id = joypad_id
	if not changed:
		return
	device_kind = next_kind
	device_changed.emit(device_name(), last_joypad_id)

func device_name() -> StringName:
	return &"gamepad" if device_kind == DeviceKind.GAMEPAD else &"keyboard_mouse"

func is_gamepad_active() -> bool:
	return device_kind == DeviceKind.GAMEPAD

func prompt_for(action: StringName) -> String:
	if not is_gamepad_active():
		match action:
			&"move_left", &"move_right": return "A / D"
			&"jump": return "SPACE"
			&"attack": return "LMB"
			&"dash": return "RMB / SHIFT"
			&"pause": return "ESC"
			&"restart": return "R"
		return ""
	var playstation := _is_playstation_pad(last_joypad_id)
	match action:
		&"move_left", &"move_right": return "L-STICK / D-PAD"
		&"jump": return "✕" if playstation else "A"
		&"attack": return "□" if playstation else "X"
		&"dash": return "○" if playstation else "B"
		&"pause": return "OPTIONS" if playstation else "MENU"
		&"restart": return "✕" if playstation else "A"
	return ""

func controls_summary() -> String:
	return "%s 移动   %s 跳跃   %s 攻击   %s 闪避" % [
		prompt_for(&"move_left"), prompt_for(&"jump"),
		prompt_for(&"attack"), prompt_for(&"dash")
	]

func vibrate(weak: float, strong: float, duration: float) -> void:
	if last_joypad_id < 0 or not Input.get_connected_joypads().has(last_joypad_id):
		return
	Input.start_joy_vibration(last_joypad_id, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)

func _is_playstation_pad(device: int) -> bool:
	if device < 0:
		return false
	var pad_name := Input.get_joy_name(device).to_lower()
	return "playstation" in pad_name or "dualsense" in pad_name or "dualshock" in pad_name or "sony" in pad_name

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	if device == last_joypad_id:
		last_joypad_id = -1
		_set_device(DeviceKind.KEYBOARD_MOUSE, -1)

func _setup_actions() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"attack", &"dash", &"pause", &"restart"]:
		_ensure_action(action, 0.25)
	_add_key(&"move_left", KEY_A)
	_add_key(&"move_left", KEY_LEFT)
	_add_key(&"move_right", KEY_D)
	_add_key(&"move_right", KEY_RIGHT)
	_add_key(&"jump", KEY_SPACE)
	_add_key(&"jump", KEY_W)
	_add_key(&"jump", KEY_UP)
	_add_key(&"attack", KEY_J)
	_add_key(&"attack", KEY_Z)
	_add_mouse_button(&"attack", MOUSE_BUTTON_LEFT)
	_add_key(&"dash", KEY_K)
	_add_key(&"dash", KEY_X)
	_add_key(&"dash", KEY_SHIFT)
	_add_mouse_button(&"dash", MOUSE_BUTTON_RIGHT)
	_add_key(&"pause", KEY_ESCAPE)
	_add_key(&"pause", KEY_P)
	_add_key(&"restart", KEY_R)
	_add_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(&"move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button(&"jump", JOY_BUTTON_A)
	_add_joy_button(&"attack", JOY_BUTTON_X)
	_add_joy_button(&"dash", JOY_BUTTON_B)
	_add_joy_button(&"pause", JOY_BUTTON_START)
	_add_ui_navigation()

func _ensure_action(action: StringName, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)

func _add_key(action: StringName, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	_add_event_once(action, event)

func _add_mouse_button(action: StringName, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	_add_event_once(action, event)

func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_add_event_once(action, event)

func _add_joy_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_event_once(action, event)

func _add_event_once(action: StringName, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event):
			return
	InputMap.action_add_event(action, event)

func _add_ui_navigation() -> void:
	for action in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
	_add_key(&"ui_up", KEY_W)
	_add_key(&"ui_down", KEY_S)
	_add_key(&"ui_left", KEY_A)
	_add_key(&"ui_right", KEY_D)
	_add_joy_button(&"ui_accept", JOY_BUTTON_A)
	_add_joy_button(&"ui_cancel", JOY_BUTTON_B)
	_add_joy_button(&"ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
