extends CharacterBody2D

signal defeated(enemy: Node)

enum Kind { MELEE, RANGED }

var kind: Kind = Kind.MELEE
var target: CharacterBody2D
var home_x := 0.0
var facing := -1.0
var health := 3
var max_health := 3
var attack_cooldown := 0.0
var shot_cooldown := 0.8
var hurt_time := 0.0
var flash_time := 0.0
var dead := false
var walk_phase := 0.0
var patrol_direction := -1.0

const GRAVITY := 1700.0

func _ready() -> void:
	home_x = position.x
	collision_layer = 4
	collision_mask = 1
	if kind == Kind.RANGED:
		health = 2
		max_health = 2
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 15.0
	capsule.height = 43.0
	collider.shape = capsule
	add_child(collider)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	flash_time = maxf(flash_time - delta, 0.0)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		move_and_slide()
		return

	var offset := target.global_position - global_position
	var distance := absf(offset.x)
	if hurt_time <= 0.0:
		if kind == Kind.MELEE:
			_update_melee(offset, distance, delta)
		else:
			_update_ranged(offset, distance, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

	move_and_slide()
	walk_phase += absf(velocity.x) * delta * 0.035
	if absf(velocity.x) > 8.0:
		facing = signf(velocity.x)
	if offset.length() < 47.0 and attack_cooldown <= 0.0:
		target.take_damage(1, Vector2(signf(offset.x) * 280.0, -190.0))
		attack_cooldown = 1.0
	if global_position.y > 900.0:
		die()
	queue_redraw()

func _update_melee(offset: Vector2, distance: float, delta: float) -> void:
	if distance < 430.0 and absf(offset.y) < 180.0:
		velocity.x = move_toward(velocity.x, signf(offset.x) * 115.0, 700.0 * delta)
	else:
		if absf(position.x - home_x) > 125.0:
			patrol_direction = -signf(position.x - home_x)
		velocity.x = move_toward(velocity.x, patrol_direction * 62.0, 450.0 * delta)
	if is_on_wall():
		patrol_direction *= -1.0

func _update_ranged(offset: Vector2, distance: float, delta: float) -> void:
	if distance < 220.0:
		velocity.x = move_toward(velocity.x, -signf(offset.x) * 95.0, 620.0 * delta)
	elif distance > 440.0 and distance < 720.0:
		velocity.x = move_toward(velocity.x, signf(offset.x) * 72.0, 520.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
	if distance < 700.0 and absf(offset.y) < 230.0 and shot_cooldown <= 0.0:
		var game := get_tree().get_first_node_in_group("game")
		if game and game.has_method("spawn_projectile"):
			game.spawn_projectile(global_position + Vector2(signf(offset.x) * 24.0, -8.0), offset.normalized())
		shot_cooldown = 1.65
		facing = signf(offset.x)

func take_damage(amount: int, knockback := Vector2.ZERO) -> void:
	if dead:
		return
	health -= amount
	velocity = knockback
	hurt_time = 0.22
	flash_time = 0.12
	if health <= 0:
		die()
	queue_redraw()

func die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", facing * 1.4, 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y - 26.0, 0.16)
	tween.tween_property(self, "modulate:a", 0.0, 0.42).set_delay(0.13)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	var bob := sin(walk_phase) * 2.0 if absf(velocity.x) > 8.0 and is_on_floor() else 0.0
	var tint := Color.WHITE if flash_time <= 0.0 else Color("fff3b0")
	var armor := Color("8d5a72") if kind == Kind.MELEE else Color("5e548e")
	armor *= tint
	# Shadow, boots and body.
	draw_oval(Vector2(0, 24), Vector2(22, 6), Color(0.05, 0.05, 0.08, 0.28))
	draw_rect(Rect2(-14, 14 + bob, 10, 10), Color("322c3e"))
	draw_rect(Rect2(4, 14 - bob, 10, 10), Color("322c3e"))
	draw_rect(Rect2(-18, -12, 36, 32), armor)
	# Hood/helmet and glowing eyes.
	draw_circle(Vector2(0, -15), 20.0, Color("29243a") * tint)
	draw_polygon(PackedVector2Array([Vector2(-18,-19), Vector2(0,-36), Vector2(18,-19)]), PackedColorArray([armor]))
	draw_rect(Rect2(-13, -19, 26, 12), Color("14131f"))
	draw_circle(Vector2(-6, -13), 2.5, Color("ffcf56"))
	draw_circle(Vector2(6, -13), 2.5, Color("ffcf56"))
	if kind == Kind.MELEE:
		var side := facing
		draw_line(Vector2(15 * side, -1), Vector2(31 * side, 18), Color("c9d6df"), 5.0)
		draw_line(Vector2(11 * side, 2), Vector2(20 * side, -5), Color("f4d35e"), 4.0)
	else:
		draw_arc(Vector2(17 * facing, 0), 13.0, -1.3 if facing > 0 else 1.8, 1.3 if facing > 0 else 4.4, 14, Color("e6b566"), 3.0)
	# Health pips.
	for i in max_health:
		var color := Color("ff6b6b") if i < health else Color(0.18, 0.16, 0.23, 0.8)
		draw_rect(Rect2(-14 + i * 10, -45, 8, 3), color)

func draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
