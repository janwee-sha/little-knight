extends SceneTree

const SUCCESS_MARKER := "Godot input parity audit: PASS"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await process_frame
	var contract_path := _argument_value("--contract")
	if contract_path.is_empty():
		failures.append("Missing required --contract argument")
	else:
		_audit_contract(contract_path)
	await _cleanup()
	if failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
	else:
		push_error("Godot input parity audit: %d failure(s)" % failures.size())
		for failure in failures:
			push_error(" - " + failure)
		quit(1)


func _audit_contract(contract_path: String) -> void:
	if not FileAccess.file_exists(contract_path):
		failures.append("Contract does not exist: %s" % contract_path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(contract_path))
	if not parsed is Dictionary:
		failures.append("Contract must contain a JSON object: %s" % contract_path)
		return
	var contract: Dictionary = parsed
	var actions = contract.get("actions")
	if not actions is Dictionary or actions.is_empty():
		failures.append("Contract must contain a non-empty actions object")
		return
	for action_name in actions:
		_audit_action(StringName(action_name), actions[action_name])


func _audit_action(action: StringName, raw_definition) -> void:
	if not raw_definition is Dictionary:
		failures.append("%s definition must be an object" % action)
		return
	if not InputMap.has_action(action):
		failures.append("Missing action: %s" % action)
		return
	var definition: Dictionary = raw_definition
	var devices: Dictionary = {}
	var event_types: Dictionary = {}
	var events := InputMap.action_get_events(action)
	for event in events:
		var device := _device_for(event)
		var event_type := _event_type_for(event)
		if not device.is_empty():
			devices[device] = true
		if not event_type.is_empty():
			event_types[event_type] = true
	for required_device in definition.get("devices", []):
		if not devices.has(String(required_device)):
			failures.append("%s lacks %s coverage" % [action, required_device])
	for required_type in definition.get("event_types", []):
		if not event_types.has(String(required_type)):
			failures.append("%s lacks %s event" % [action, required_type])
	var deadzone := InputMap.action_get_deadzone(action)
	if definition.has("deadzone_min") and deadzone < float(definition["deadzone_min"]):
		failures.append("%s deadzone %.3f is below %.3f" % [
			action, deadzone, float(definition["deadzone_min"])
		])
	if definition.has("deadzone_max") and deadzone > float(definition["deadzone_max"]):
		failures.append("%s deadzone %.3f is above %.3f" % [
			action, deadzone, float(definition["deadzone_max"])
		])
	print("[input] %s deadzone=%.3f devices=%s events=%s" % [
		action, deadzone, devices.keys(), event_types.keys()
	])


func _device_for(event: InputEvent) -> String:
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return "mouse"
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "gamepad"
	return ""


func _event_type_for(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key"
	if event is InputEventMouseButton:
		return "mouse_button"
	if event is InputEventMouseMotion:
		return "mouse_motion"
	if event is InputEventJoypadButton:
		return "joy_button"
	if event is InputEventJoypadMotion:
		return "joy_axis"
	return ""


func _argument_value(name: String) -> String:
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index] == name and index + 1 < arguments.size():
			return arguments[index + 1]
	return ""


func _cleanup() -> void:
	var audio := root.get_node_or_null("AudioManager")
	if audio and audio.has_method("release_for_shutdown"):
		audio.release_for_shutdown()
	for child in root.get_children():
		if is_instance_valid(child):
			child.free()
	await process_frame
