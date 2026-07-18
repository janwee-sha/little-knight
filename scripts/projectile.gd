extends Area2D

const SPRITE_LIBRARY := preload("res://scripts/sprite_library.gd")

var velocity := Vector2.ZERO
var life := 4.0
var active := true

func setup(start: Vector2, direction: Vector2) -> void:
	position = start
	velocity = direction.normalized() * 155.0
	collision_layer = 4
	collision_mask = 2 | 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.5
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var animations := [
		{"name": &"flight", "frames": 4, "fps": 14.0, "loop": true},
	]
	var sprite := SPRITE_LIBRARY.create_animated_sprite("projectile", animations, 64, 0.36)
	sprite.position = Vector2.ZERO
	add_child(sprite)
	SPRITE_LIBRARY.play(sprite, &"flight")
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	if not active:
		return
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.has_method("take_damage"):
		body.take_damage(1, velocity.normalized() * 115.0 + Vector2.UP * 45.0)
	burst(false)

func take_damage(_amount: int, _knockback := Vector2.ZERO) -> bool:
	burst(true)
	return false

func burst(parried := false) -> void:
	if not active:
		return
	active = false
	monitoring = false
	AudioManager.play_world(&"projectile_burst", global_position, 0.055, -2.0)
	if parried:
		FeedbackDirector.request_hit(global_position, false, false, Color("ffb45a"))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.1, 2.1), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)
