extends Area2D

signal collected(relic: Area2D, collector: Node)

var collected_state := false
var _float_time := 0.0


func _ready() -> void:
	add_to_group("health_relic")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape_node.shape = circle
	add_child(shape_node)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	_float_time += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if collected_state or not body.has_method("increase_max_health"):
		return
	collected_state = true
	monitoring = false
	collected.emit(self, body)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.75, 1.75), 0.24)
	tween.tween_property(self, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var bob := roundf(sin(_float_time * 3.2) * 1.5)
	var center := Vector2(0, -2 + bob)
	draw_circle(center, 12.0, Color(0.35, 1.0, 0.92, 0.08))
	draw_arc(center, 10.0, 0.0, TAU, 16, Color(0.55, 1.0, 0.94, 0.42), 1.0)
	var crystal := PackedVector2Array([
		center + Vector2(0, -8), center + Vector2(7, -1),
		center + Vector2(0, 9), center + Vector2(-7, -1),
	])
	draw_colored_polygon(crystal, Color("75e9df"))
	draw_polyline(PackedVector2Array([
		crystal[0], crystal[1], crystal[2], crystal[3], crystal[0],
	]), Color("d7fff1"), 1.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-3, -2), center + Vector2(0, 1),
		center + Vector2(3, -2), center + Vector2(0, 5),
	]), Color("ffd36c"))
