extends Area2D

var velocity := Vector2.ZERO
var life := 4.0
var active := true

func setup(start: Vector2, direction: Vector2) -> void:
	position = start
	velocity = direction.normalized() * 310.0
	collision_layer = 4
	collision_mask = 2 | 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active:
		return
	position += velocity * delta
	rotation += delta * 5.0
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, velocity.normalized() * 230.0 + Vector2.UP * 90.0)
	burst()

func take_damage(_amount: int, _knockback := Vector2.ZERO) -> void:
	burst()

func burst() -> void:
	if not active:
		return
	active = false
	monitoring = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.1, 2.1), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.35, 0.22, 0.18))
	draw_circle(Vector2.ZERO, 11.0, Color("ff5a3d"))
	draw_circle(Vector2(-3, -3), 5.0, Color("ffd166"))
	for i in 4:
		var angle := float(i) * TAU / 4.0
		var tip := Vector2.from_angle(angle) * 16.0
		draw_line(Vector2.from_angle(angle) * 9.0, tip, Color("ff8a3d"), 3.0)
