extends Node

const HIT_SPARK_SCRIPT := preload("res://scripts/hit_spark.gd")

var _camera: Camera2D
var _hitstop_end_msec := 0
var _hitstop_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if _hitstop_active and Time.get_ticks_msec() >= _hitstop_end_msec:
		Engine.time_scale = 1.0
		_hitstop_active = false

func register_camera(camera: Camera2D) -> void:
	_camera = camera

func request_hit(world_position: Vector2, lethal := false, player_hurt := false, color := Color("fff3b0")) -> void:
	var duration := 5.0 / 60.0 if lethal else (4.0 / 60.0 if player_hurt else 3.0 / 60.0)
	_start_hitstop(duration)
	if is_instance_valid(_camera) and _camera.has_method("add_shake"):
		_camera.add_shake(4.0 if lethal or player_hurt else 2.0)
	var spark := HIT_SPARK_SCRIPT.new()
	spark.global_position = world_position
	spark.spark_color = color
	spark.intensity = 1.6 if lethal else 1.0
	var effects_parent := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	effects_parent.add_child(spark)
	if player_hurt:
		InputRouter.vibrate(0.42, 0.72, 0.12)
	elif lethal:
		InputRouter.vibrate(0.38, 0.62, 0.12)
	else:
		InputRouter.vibrate(0.18, 0.34, 0.06)

func reset() -> void:
	Engine.time_scale = 1.0
	_hitstop_active = false
	_hitstop_end_msec = 0

func _start_hitstop(duration: float) -> void:
	var requested_end := Time.get_ticks_msec() + int(duration * 1000.0)
	_hitstop_end_msec = maxi(_hitstop_end_msec, requested_end)
	Engine.time_scale = 0.05
	_hitstop_active = true
