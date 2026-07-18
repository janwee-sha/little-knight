extends Node2D

var spark_color := Color("fff3b0")
var intensity := 1.0
var _life := 0.18
var _rays: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("transient_feedback")
	for i in 8:
		var direction := Vector2.from_angle(TAU * float(i) / 8.0 + randf_range(-0.18, 0.18))
		_rays.append({"position": Vector2.ZERO, "velocity": direction * randf_range(55.0, 105.0) * intensity})
	queue_redraw()

func _process(delta: float) -> void:
	_life -= delta
	for ray in _rays:
		ray.position += ray.velocity * delta
		ray.velocity *= 0.84
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	var alpha := clampf(_life / 0.18, 0.0, 1.0)
	for ray in _rays:
		var p: Vector2 = ray.position
		draw_rect(Rect2(Vector2(roundf(p.x), roundf(p.y)), Vector2(2, 2)), Color(spark_color, alpha))
