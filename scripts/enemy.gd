extends CharacterBody2D

signal defeated(enemy: Node)
signal damaged(amount: int)
signal attack_telegraphed(enemy: Node, kind: int)

enum Kind { MELEE, RANGED }
enum AttackState { NONE, WINDUP, ACTIVE, RECOVERY, CAST }

const SPRITE_LIBRARY := preload("res://scripts/sprite_library.gd")
const GRAVITY := 850.0
const MELEE_WINDUP := 12.0 / 60.0
const MELEE_ACTIVE := 4.0 / 60.0
const MELEE_RECOVERY := 20.0 / 60.0
const RANGED_CAST := 18.0 / 60.0

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
var attack_state := AttackState.NONE
var attack_state_time := 0.0
var attack_area: Area2D
var sprite: AnimatedSprite2D
var _attack_hit := false

func _ready() -> void:
	home_x = position.x
	collision_layer = 4
	collision_mask = 1
	if kind == Kind.RANGED:
		health = 2
		max_health = 2
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.5
	capsule.height = 22.0
	collider.shape = capsule
	add_child(collider)
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2
	attack_area.monitoring = false
	var attack_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(24, 21)
	attack_shape.shape = box
	attack_area.add_child(attack_shape)
	attack_area.body_entered.connect(_on_attack_body_entered)
	add_child(attack_area)
	_setup_sprite()
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
		velocity.x = move_toward(velocity.x, 0.0, 350.0 * delta)
		move_and_slide()
		_update_visual_state()
		return

	var offset := target.global_position - global_position
	var distance := absf(offset.x)
	if hurt_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 250.0 * delta)
	elif attack_state != AttackState.NONE:
		_update_attack_state(delta, offset)
	elif kind == Kind.MELEE:
		_update_melee(offset, distance, delta)
	else:
		_update_ranged(offset, distance, delta)

	move_and_slide()
	walk_phase += absf(velocity.x) * delta * 0.07
	if attack_state == AttackState.NONE and absf(velocity.x) > 4.0:
		facing = signf(velocity.x)
	attack_area.position.x = facing * 15.0
	if global_position.y > 450.0:
		die()
	_update_visual_state()
	queue_redraw()

func _update_melee(offset: Vector2, distance: float, delta: float) -> void:
	if distance < 34.0 and absf(offset.y) < 26.0 and attack_cooldown <= 0.0:
		_start_melee_attack(offset)
		return
	if distance < 215.0 and absf(offset.y) < 90.0:
		velocity.x = move_toward(velocity.x, signf(offset.x) * 57.5, 350.0 * delta)
	else:
		if absf(position.x - home_x) > 62.5:
			patrol_direction = -signf(position.x - home_x)
		velocity.x = move_toward(velocity.x, patrol_direction * 31.0, 225.0 * delta)
	if is_on_wall():
		patrol_direction *= -1.0

func _update_ranged(offset: Vector2, distance: float, delta: float) -> void:
	if distance < 110.0:
		velocity.x = move_toward(velocity.x, -signf(offset.x) * 47.5, 310.0 * delta)
	elif distance > 220.0 and distance < 360.0:
		velocity.x = move_toward(velocity.x, signf(offset.x) * 36.0, 260.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 325.0 * delta)
	if distance < 350.0 and absf(offset.y) < 115.0 and shot_cooldown <= 0.0:
		_start_ranged_cast(offset)

func _start_melee_attack(offset: Vector2) -> void:
	attack_state = AttackState.WINDUP
	attack_state_time = MELEE_WINDUP
	attack_cooldown = 1.0
	facing = signf(offset.x) if offset.x != 0.0 else facing
	velocity.x = 0.0
	_attack_hit = false
	attack_telegraphed.emit(self, kind)
	AudioManager.play_world(&"enemy_tell", global_position, 0.03, -4.0)
	SPRITE_LIBRARY.play(sprite, &"attack", true)

func _start_ranged_cast(offset: Vector2) -> void:
	attack_state = AttackState.CAST
	attack_state_time = RANGED_CAST
	shot_cooldown = 1.65
	facing = signf(offset.x) if offset.x != 0.0 else facing
	velocity.x = 0.0
	attack_telegraphed.emit(self, kind)
	AudioManager.play_world(&"cast", global_position, 0.035, -4.0)
	SPRITE_LIBRARY.play(sprite, &"attack", true)

func _update_attack_state(delta: float, offset: Vector2) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)
	attack_state_time -= delta
	if attack_state_time > 0.0:
		return
	match attack_state:
		AttackState.WINDUP:
			attack_state = AttackState.ACTIVE
			attack_state_time = MELEE_ACTIVE
			attack_area.set_deferred("monitoring", true)
			_check_attack_overlap.call_deferred()
		AttackState.ACTIVE:
			attack_state = AttackState.RECOVERY
			attack_state_time = MELEE_RECOVERY
			attack_area.set_deferred("monitoring", false)
		AttackState.RECOVERY:
			attack_state = AttackState.NONE
		AttackState.CAST:
			var game := get_tree().get_first_node_in_group("game")
			if game and game.has_method("spawn_projectile") and is_instance_valid(target):
				var direction := (target.global_position - global_position).normalized()
				game.spawn_projectile(global_position + Vector2(facing * 12.0, -4.0), direction)
			attack_state = AttackState.NONE

func _on_attack_body_entered(body: Node) -> void:
	_hit_melee_target(body)

func _check_attack_overlap() -> void:
	if attack_state != AttackState.ACTIVE:
		return
	for body in attack_area.get_overlapping_bodies():
		_hit_melee_target(body)

func _hit_melee_target(body: Node) -> void:
	if _attack_hit or attack_state != AttackState.ACTIVE or not body.has_method("take_damage"):
		return
	_attack_hit = true
	body.take_damage(1, Vector2(facing * 140.0, -95.0))

func take_damage(amount: int, knockback := Vector2.ZERO) -> bool:
	if dead:
		return false
	health -= amount
	velocity = knockback
	hurt_time = 0.22
	flash_time = 0.12
	_cancel_attack()
	var lethal := health <= 0
	damaged.emit(amount)
	AudioManager.play_world(&"hit", global_position, 0.05, -1.0)
	SPRITE_LIBRARY.play(sprite, &"hurt", true)
	FeedbackDirector.request_hit(global_position + Vector2(0, -8), lethal, false, Color("fff3b0"))
	if lethal:
		die()
	queue_redraw()
	return lethal

func die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	_cancel_attack()
	defeated.emit(self)
	SPRITE_LIBRARY.play(sprite, &"death", true)
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)

func _cancel_attack() -> void:
	attack_state = AttackState.NONE
	attack_state_time = 0.0
	_attack_hit = false
	if is_instance_valid(attack_area):
		attack_area.set_deferred("monitoring", false)

func _setup_sprite() -> void:
	var attack_fps := 11.0 if kind == Kind.MELEE else 20.0
	var animations := [
		{"name": &"idle", "frames": 4, "fps": 5.0, "loop": true},
		{"name": &"walk", "frames": 6, "fps": 10.0, "loop": true},
		{"name": &"attack", "frames": 6, "fps": attack_fps, "loop": false},
		{"name": &"hurt", "frames": 2, "fps": 8.0, "loop": false},
		{"name": &"death", "frames": 6, "fps": 11.0, "loop": false},
	]
	var character := "melee_guard" if kind == Kind.MELEE else "ranged_guard"
	sprite = SPRITE_LIBRARY.create_animated_sprite(character, animations)
	add_child(sprite)
	SPRITE_LIBRARY.play(sprite, &"idle")


func _update_visual_state() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.flip_h = facing < 0.0
	sprite.modulate = Color("fff0c4") if flash_time > 0.0 else Color.WHITE
	if dead:
		SPRITE_LIBRARY.play(sprite, &"death")
	elif hurt_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"hurt")
	elif attack_state != AttackState.NONE:
		SPRITE_LIBRARY.play(sprite, &"attack")
	elif absf(velocity.x) > 4.0:
		SPRITE_LIBRARY.play(sprite, &"walk")
	else:
		SPRITE_LIBRARY.play(sprite, &"idle")


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 1), Vector2(-7, -1), Vector2(7, -1), Vector2(11, 1),
		Vector2(7, 3), Vector2(-7, 3)
	]), Color(0.03, 0.02, 0.06, 0.42))
	if attack_state == AttackState.WINDUP or attack_state == AttackState.CAST:
		var pulse := 0.55 + sin(Time.get_ticks_msec() * 0.04) * 0.22
		var tell_color := Color(1.0, 0.31, 0.24, pulse) if kind == Kind.MELEE else Color(0.82, 0.35, 1.0, pulse)
		draw_arc(Vector2(0, -14), 18.0, 0.0, TAU, 24, tell_color, 2.0)
		draw_arc(Vector2(0, -14), 13.0, -PI * 0.5, PI * 1.5, 18, Color(tell_color, pulse * 0.45), 1.0)
	for i in max_health:
		var pip_color := Color("ff6b6b") if i < health else Color(0.18, 0.16, 0.23, 0.8)
		draw_rect(Rect2(-7 + i * 5, -36, 4, 2), pip_color)
