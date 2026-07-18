extends Node

signal sfx_volume_changed(value: float)

const SETTINGS_PATH := "user://settings.cfg"

var sfx_volume := 0.82

func _ready() -> void:
	_load_settings()

func set_sfx_volume(value: float, persist := true) -> void:
	var next_value := clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, next_value):
		return
	sfx_volume = next_value
	sfx_volume_changed.emit(sfx_volume)
	if persist:
		_save_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)
