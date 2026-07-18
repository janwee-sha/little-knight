extends Camera2D

var shake_strength := 0.0
var _noise_time := 0.0

func _ready() -> void:
	position = Vector2(90, -35)
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	limit_left = 0
	limit_right = 2800
	limit_top = 0
	limit_bottom = 360
	position_smoothing_enabled = true
	FeedbackDirector.register_camera(self)

func _process(delta: float) -> void:
	_noise_time += delta * 42.0
	shake_strength = move_toward(shake_strength, 0.0, delta * 15.0)
	if shake_strength <= 0.05:
		offset = Vector2.ZERO
		return
	var shake := Vector2(sin(_noise_time * 1.71), cos(_noise_time * 2.13)) * shake_strength
	offset = Vector2(roundf(shake.x), roundf(shake.y))

func add_shake(strength: float) -> void:
	shake_strength = maxf(shake_strength, strength)
