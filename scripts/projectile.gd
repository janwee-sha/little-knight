extends Area2D

const COMBAT := preload("res://scripts/combat_rules.gd")
const SPRITE_LIBRARY := preload("res://scripts/sprite_library.gd")

var velocity := Vector2.ZERO
var life := 4.0
var active := true
var attack_type := COMBAT.AttackType.NORMAL

func setup(start: Vector2, direction: Vector2, type_value := COMBAT.AttackType.NORMAL) -> void:
	position = start
	attack_type = type_value
	var speed := 230.0 if attack_type == COMBAT.AttackType.RED else 185.0
	velocity = direction.normalized() * speed
	collision_layer = 4
	collision_mask = 2 | 1
	monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.5 if attack_type == COMBAT.AttackType.RED else 5.5
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	var animations := [
		{"name": &"flight", "frames": 4, "fps": 14.0, "loop": true},
	]
	var sprite := SPRITE_LIBRARY.create_animated_sprite("projectile", animations, 64, 0.36)
	sprite.position = Vector2.ZERO
	if attack_type == COMBAT.AttackType.RED:
		sprite.modulate = Color("ff4545")
		sprite.scale *= 1.25
	add_child(sprite)
	SPRITE_LIBRARY.play(sprite, &"flight")
	rotation = velocity.angle()
	queue_redraw()

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
	if body.has_method("receive_combat_hit"):
		var damage := COMBAT.health_damage_for(attack_type)
		var hit := COMBAT.HitData.new(
			attack_type,
			damage,
			14.0 if attack_type == COMBAT.AttackType.NORMAL else 0.0,
			18.0 if attack_type == COMBAT.AttackType.NORMAL else 0.0,
			velocity.normalized() * 145.0 + Vector2.UP * 55.0,
			self
		)
		var result := int(body.receive_combat_hit(hit))
		if result != COMBAT.HitResult.EVADED:
			burst(result == COMBAT.HitResult.PERFECT_GUARD)
		return
	if body.has_method("take_damage"):
		body.take_damage(COMBAT.health_damage_for(attack_type), velocity.normalized() * 125.0 + Vector2.UP * 45.0)
	burst(false)

func take_damage(_amount: int, _knockback := Vector2.ZERO) -> bool:
	if attack_type == COMBAT.AttackType.RED:
		AudioManager.play_world(&"guard_block", global_position, 0.0, -5.0)
		return false
	burst(true)
	return false

func burst(parried := false) -> void:
	if not active:
		return
	active = false
	monitoring = false
	AudioManager.play_world(&"projectile_burst", global_position, 0.055, -2.0)
	if parried:
		FeedbackDirector.request_hit(global_position, false, false, Color("ffe36e"))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.1, 2.1), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	if attack_type != COMBAT.AttackType.RED:
		return
	draw_arc(Vector2.ZERO, 8.5, 0.0, TAU, 16, Color(1.0, 0.14, 0.12, 0.9), 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)
	]), Color(1.0, 0.25, 0.18, 0.55))
