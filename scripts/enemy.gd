extends CharacterBody2D

signal defeated(enemy: Node)
signal damaged(amount: int)
signal attack_telegraphed(enemy: Node, attack_type: int)

enum Kind { MELEE, RANGED }
enum AttackState { NONE, WINDUP, ACTIVE, RECOVERY, CAST }

const COMBAT := preload("res://scripts/combat_rules.gd")
const SPRITE_LIBRARY := preload("res://scripts/sprite_library.gd")
const GRAVITY := 850.0

var kind: Kind = Kind.MELEE
var target: CharacterBody2D
var encounter_id := 0
var encounter_active := false
var home_x := 0.0
var facing := -1.0
var health := 8
var max_health := 8
var poise := 4
var max_poise := 4
var poise_recovery_time := 0.0
var attack_cooldown := 0.45
var hurt_time := 0.0
var parried_time := 0.0
var flash_time := 0.0
var dead := false
var walk_phase := 0.0
var patrol_direction := -1.0
var attack_state := AttackState.NONE
var attack_state_time := 0.0
var current_attack_type := COMBAT.AttackType.NORMAL
var last_attack_type := -1
var attack_area: Area2D
var attack_box: RectangleShape2D
var sprite: AnimatedSprite2D
var ground_offset := 0.0
var _attack_hit := false
var _attack_slot_reserved := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	home_x = position.x
	collision_layer = 4
	collision_mask = 1
	_rng.seed = get_instance_id()
	if kind == Kind.RANGED:
		health = 5
		max_health = 5
		poise = 3
		max_poise = 3
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.5
	capsule.height = 22.0
	collider.shape = capsule
	add_child(collider)
	ground_offset = collider.position.y + capsule.height * 0.5
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2
	attack_area.monitoring = false
	var attack_shape := CollisionShape2D.new()
	attack_box = RectangleShape2D.new()
	attack_box.size = Vector2(24, 21)
	attack_shape.shape = attack_box
	attack_area.add_child(attack_shape)
	attack_area.body_entered.connect(_on_attack_body_entered)
	add_child(attack_area)
	_setup_sprite()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	parried_time = maxf(parried_time - delta, 0.0)
	flash_time = maxf(flash_time - delta, 0.0)
	poise_recovery_time = maxf(poise_recovery_time - delta, 0.0)
	if poise_recovery_time <= 0.0 and poise < max_poise and hurt_time <= 0.0:
		poise = max_poise
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0.0, 350.0 * delta)
		move_and_slide()
		_update_visual_state()
		return

	var offset := target.global_position - global_position
	var distance := absf(offset.x)
	if not encounter_active:
		var alert_range := 360.0 if kind == Kind.RANGED else 235.0
		if distance <= alert_range and absf(offset.y) < 100.0:
			var game := get_tree().get_first_node_in_group("game")
			if game and game.has_method("activate_encounter"):
				game.activate_encounter(encounter_id)
		else:
			_update_patrol(delta)
	elif hurt_time > 0.0 or parried_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)
	elif attack_state != AttackState.NONE:
		_update_attack_state(delta)
	elif kind == Kind.MELEE:
		_update_melee(offset, distance, delta)
	else:
		_update_ranged(offset, distance, delta)

	move_and_slide()
	walk_phase += absf(velocity.x) * delta * 0.07
	if attack_state == AttackState.NONE and absf(velocity.x) > 4.0 and hurt_time <= 0.0:
		facing = signf(velocity.x)
	attack_area.position.x = facing * _attack_offset(current_attack_type)
	if global_position.y > 450.0:
		die()
	_update_visual_state()
	queue_redraw()

func _update_patrol(delta: float) -> void:
	if absf(position.x - home_x) > 62.5:
		patrol_direction = -signf(position.x - home_x)
	velocity.x = move_toward(velocity.x, patrol_direction * 28.0, 210.0 * delta)
	if is_on_wall():
		patrol_direction *= -1.0

func _update_melee(offset: Vector2, distance: float, delta: float) -> void:
	if distance < 78.0 and absf(offset.y) < 30.0 and attack_cooldown <= 0.0:
		var next_attack := _choose_melee_attack(distance)
		if next_attack >= 0 and _request_attack_slot(next_attack):
			_start_melee_attack(offset, next_attack, true)
			return
	if distance < 250.0 and absf(offset.y) < 90.0:
		velocity.x = move_toward(velocity.x, signf(offset.x) * 67.5, 380.0 * delta)
	else:
		_update_patrol(delta)

func _choose_melee_attack(distance: float) -> int:
	if distance > 43.0:
		return COMBAT.AttackType.RED if last_attack_type != COMBAT.AttackType.RED else COMBAT.AttackType.YELLOW
	var roll := _rng.randf()
	if roll < 0.5:
		return COMBAT.AttackType.NORMAL
	if roll < 0.8:
		return COMBAT.AttackType.YELLOW
	if last_attack_type != COMBAT.AttackType.RED:
		return COMBAT.AttackType.RED
	return COMBAT.AttackType.YELLOW

func _update_ranged(offset: Vector2, distance: float, delta: float) -> void:
	if distance < 112.0:
		velocity.x = move_toward(velocity.x, -signf(offset.x) * 52.5, 330.0 * delta)
	elif distance > 225.0 and distance < 390.0:
		velocity.x = move_toward(velocity.x, signf(offset.x) * 39.0, 275.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 335.0 * delta)
	if distance < 370.0 and absf(offset.y) < 120.0 and attack_cooldown <= 0.0:
		var next_attack := COMBAT.AttackType.NORMAL
		if last_attack_type >= 0 and last_attack_type != COMBAT.AttackType.RED and _rng.randf() < 0.25:
			next_attack = COMBAT.AttackType.RED
		if _request_attack_slot(next_attack):
			_start_ranged_cast(offset, next_attack, true)

func _request_attack_slot(attack_type: int) -> bool:
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("request_enemy_attack"):
		return bool(game.request_enemy_attack(self, attack_type))
	return true

func _start_melee_attack(offset: Vector2, attack_type := COMBAT.AttackType.NORMAL, slot_reserved := false) -> void:
	current_attack_type = attack_type
	last_attack_type = attack_type
	attack_state = AttackState.WINDUP
	attack_state_time = _windup_for(attack_type) + _tutorial_delay_for(attack_type)
	attack_cooldown = 99.0
	facing = signf(offset.x) if not is_zero_approx(offset.x) else facing
	velocity.x = 0.0
	_attack_hit = false
	_attack_slot_reserved = slot_reserved
	_configure_attack_box(attack_type)
	attack_telegraphed.emit(self, attack_type)
	AudioManager.play_world(_tell_sound_for(attack_type), global_position, 0.025, -4.0)
	SPRITE_LIBRARY.play(sprite, _animation_for_attack(attack_type), true)

func _start_ranged_cast(offset: Vector2, attack_type := COMBAT.AttackType.NORMAL, slot_reserved := false) -> void:
	current_attack_type = attack_type
	last_attack_type = attack_type
	attack_state = AttackState.CAST
	attack_state_time = (36.0 / 60.0 if attack_type == COMBAT.AttackType.RED else 16.0 / 60.0) + _tutorial_delay_for(attack_type)
	attack_cooldown = 99.0
	facing = signf(offset.x) if not is_zero_approx(offset.x) else facing
	velocity.x = 0.0
	_attack_slot_reserved = slot_reserved
	attack_telegraphed.emit(self, attack_type)
	AudioManager.play_world(_tell_sound_for(attack_type), global_position, 0.02, -4.0)
	SPRITE_LIBRARY.play(sprite, _animation_for_attack(attack_type), true)

func _tutorial_delay_for(attack_type: int) -> float:
	var key := _tutorial_key_for(attack_type)
	if RunState.has_seen_tutorial(key):
		return 0.0
	RunState.mark_tutorial(key)
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("show_combat_tutorial"):
		game.show_combat_tutorial(attack_type)
	return 0.45

func _tutorial_key_for(attack_type: int) -> StringName:
	match attack_type:
		COMBAT.AttackType.YELLOW: return &"yellow_attack"
		COMBAT.AttackType.RED: return &"red_attack"
	return &"normal_attack"

func _update_attack_state(delta: float) -> void:
	if attack_state == AttackState.ACTIVE:
		velocity.x = facing * _lunge_speed(current_attack_type)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)
	attack_state_time -= delta
	if attack_state_time > 0.0:
		return
	match attack_state:
		AttackState.WINDUP:
			attack_state = AttackState.ACTIVE
			attack_state_time = _active_for(current_attack_type)
			attack_area.set_deferred("monitoring", true)
			_check_attack_overlap.call_deferred()
		AttackState.ACTIVE:
			attack_state = AttackState.RECOVERY
			attack_state_time = _recovery_for(current_attack_type)
			attack_area.set_deferred("monitoring", false)
		AttackState.RECOVERY:
			_finish_attack()
		AttackState.CAST:
			var game := get_tree().get_first_node_in_group("game")
			if game and game.has_method("spawn_projectile") and is_instance_valid(target):
				var direction := (target.global_position - global_position).normalized()
				game.spawn_projectile(global_position + Vector2(facing * 12.0, -4.0), direction, current_attack_type)
			attack_cooldown = 2.4 if current_attack_type == COMBAT.AttackType.RED else 1.4
			attack_state = AttackState.NONE
			_release_attack_slot()

func _finish_attack() -> void:
	attack_state = AttackState.NONE
	attack_cooldown = _rng.randf_range(0.75, 1.05)
	_release_attack_slot()

func _release_attack_slot() -> void:
	if not _attack_slot_reserved:
		return
	_attack_slot_reserved = false
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("release_enemy_attack"):
		game.release_enemy_attack(self)

func _on_attack_body_entered(body: Node) -> void:
	_hit_melee_target(body)

func _check_attack_overlap() -> void:
	if attack_state != AttackState.ACTIVE:
		return
	for body in attack_area.get_overlapping_bodies():
		_hit_melee_target(body)

func _hit_melee_target(body: Node) -> void:
	if _attack_hit or attack_state != AttackState.ACTIVE:
		return
	_attack_hit = true
	var damage := 3 if current_attack_type == COMBAT.AttackType.RED else 2
	var guard_cost := 18.0 if current_attack_type == COMBAT.AttackType.NORMAL else 0.0
	var perfect_cost := 28.0 if current_attack_type == COMBAT.AttackType.YELLOW else 22.0
	var knockback := Vector2(facing * (205.0 if current_attack_type == COMBAT.AttackType.RED else 155.0), -105.0)
	var hit := COMBAT.HitData.new(current_attack_type, damage, guard_cost, perfect_cost, knockback, self)
	if body.has_method("receive_combat_hit"):
		body.receive_combat_hit(hit)
	elif body.has_method("take_damage"):
		body.take_damage(damage, knockback)

func take_combat_damage(amount: int, stagger_power: int, knockback: Vector2, _move: int) -> bool:
	if dead:
		return false
	health -= amount
	poise -= stagger_power
	poise_recovery_time = 1.25
	flash_time = 0.12
	var lethal := health <= 0
	if lethal:
		damaged.emit(amount)
		AudioManager.play_world(&"hit", global_position, 0.05, -1.0)
		FeedbackDirector.request_hit(global_position + Vector2(0, -8), true, false, Color("fff3b0"))
		die()
		return true
	if poise <= 0:
		poise = max_poise
		hurt_time = 0.55
		parried_time = 0.0
		velocity = knockback
		_cancel_attack()
		SPRITE_LIBRARY.play(sprite, &"hurt", true)
	else:
		velocity.x = knockback.x * 0.18
	damaged.emit(amount)
	AudioManager.play_world(&"hit", global_position, 0.05, -1.0)
	FeedbackDirector.request_hit(global_position + Vector2(0, -8), false, false, Color("fff3b0"))
	queue_redraw()
	return false

func take_damage(amount: int, knockback := Vector2.ZERO) -> bool:
	return take_combat_damage(amount, 1, knockback, COMBAT.PlayerMove.LIGHT_ONE)

func on_parried(_by: Node) -> void:
	if dead:
		return
	_cancel_attack()
	parried_time = 0.9
	hurt_time = 0.9
	poise = max_poise
	velocity.x = -facing * 55.0
	AudioManager.play_world(&"perfect_guard", global_position, 0.01, 0.0)
	SPRITE_LIBRARY.play(sprite, &"hurt", true)

func can_be_riposted() -> bool:
	return not dead and parried_time > 0.0

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
	_release_attack_slot()

func _windup_for(attack_type: int) -> float:
	match attack_type:
		COMBAT.AttackType.YELLOW: return 22.0 / 60.0
		COMBAT.AttackType.RED: return 28.0 / 60.0
	return 12.0 / 60.0

func _active_for(attack_type: int) -> float:
	return 6.0 / 60.0 if attack_type == COMBAT.AttackType.RED else (5.0 / 60.0 if attack_type == COMBAT.AttackType.YELLOW else 4.0 / 60.0)

func _recovery_for(attack_type: int) -> float:
	match attack_type:
		COMBAT.AttackType.YELLOW: return 24.0 / 60.0
		COMBAT.AttackType.RED: return 28.0 / 60.0
	return 16.0 / 60.0

func _lunge_speed(attack_type: int) -> float:
	match attack_type:
		COMBAT.AttackType.YELLOW: return 215.0
		COMBAT.AttackType.RED: return 500.0
	return 35.0

func _attack_offset(attack_type: int) -> float:
	match attack_type:
		COMBAT.AttackType.YELLOW: return 18.0
		COMBAT.AttackType.RED: return 25.0
	return 15.0

func _configure_attack_box(attack_type: int) -> void:
	match attack_type:
		COMBAT.AttackType.YELLOW:
			attack_box.size = Vector2(30, 25)
		COMBAT.AttackType.RED:
			attack_box.size = Vector2(50, 22)
		_:
			attack_box.size = Vector2(24, 21)
	attack_area.position.x = facing * _attack_offset(attack_type)

func _tell_sound_for(attack_type: int) -> StringName:
	match attack_type:
		COMBAT.AttackType.YELLOW: return &"enemy_yellow"
		COMBAT.AttackType.RED: return &"enemy_red"
	return &"enemy_tell"

func _animation_for_attack(attack_type: int) -> StringName:
	if kind == Kind.RANGED:
		return &"attack_red" if attack_type == COMBAT.AttackType.RED else &"attack"
	match attack_type:
		COMBAT.AttackType.YELLOW: return &"attack_yellow"
		COMBAT.AttackType.RED: return &"attack_red"
	return &"attack"

func _setup_sprite() -> void:
	var animations := [
		{"name": &"idle", "frames": 4, "fps": 5.0, "loop": true},
		{"name": &"walk", "frames": 6, "fps": 10.0, "loop": true},
		{"name": &"attack", "frames": 6, "fps": 11.0 if kind == Kind.MELEE else 20.0, "loop": false},
	]
	if kind == Kind.MELEE:
		animations.append({"name": &"attack_yellow", "frames": 8, "fps": 12.0, "loop": false})
	animations.append({"name": &"attack_red", "frames": 8, "fps": 12.0, "loop": false})
	animations.append_array([
		{"name": &"hurt", "frames": 2, "fps": 8.0, "loop": false},
		{"name": &"death", "frames": 6, "fps": 11.0, "loop": false},
	])
	var character := "melee_guard" if kind == Kind.MELEE else "ranged_guard"
	sprite = SPRITE_LIBRARY.create_animated_sprite(character, animations, 128, 0.52, ground_offset)
	add_child(sprite)
	SPRITE_LIBRARY.play(sprite, &"idle")

func _update_visual_state() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.flip_h = facing < 0.0
	sprite.modulate = Color("fff0c4") if flash_time > 0.0 else Color.WHITE
	if dead:
		SPRITE_LIBRARY.play(sprite, &"death")
	elif hurt_time > 0.0 or parried_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"hurt")
	elif attack_state != AttackState.NONE:
		SPRITE_LIBRARY.play(sprite, _animation_for_attack(current_attack_type))
	elif absf(velocity.x) > 4.0:
		SPRITE_LIBRARY.play(sprite, &"walk")
	else:
		SPRITE_LIBRARY.play(sprite, &"idle")

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, ground_offset + 1), Vector2(-7, ground_offset - 1),
		Vector2(7, ground_offset - 1), Vector2(11, ground_offset + 1),
		Vector2(7, ground_offset + 3), Vector2(-7, ground_offset + 3)
	]), Color(0.03, 0.02, 0.06, 0.42))
	if attack_state == AttackState.WINDUP or attack_state == AttackState.CAST:
		var pulse := 0.64 + sin(Time.get_ticks_msec() * 0.04) * 0.24
		var center := Vector2(0, ground_offset - 14)
		if current_attack_type == COMBAT.AttackType.YELLOW:
			for segment in 3:
				var start := -PI * 0.5 + segment * TAU / 3.0
				draw_arc(center, 18.0, start, start + 1.35, 8, Color(1.0, 0.83, 0.2, pulse), 2.0)
		elif current_attack_type == COMBAT.AttackType.RED:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -8), center + Vector2(8, 0),
				center + Vector2(0, 8), center + Vector2(-8, 0)
			]), Color(1.0, 0.18, 0.16, pulse * 0.8))
			draw_arc(center, 20.0, 0.0, TAU, 24, Color(1.0, 0.2, 0.16, pulse), 2.0)
			draw_arc(center, 14.0, 0.0, TAU, 20, Color(1.0, 0.55, 0.3, pulse * 0.65), 1.0)
	var pip_width := max_health * 5 - 1
	for i in max_health:
		var pip_color := Color("ff6b6b") if i < health else Color(0.18, 0.16, 0.23, 0.8)
		draw_rect(Rect2(-pip_width * 0.5 + i * 5, ground_offset - 36, 4, 2), pip_color)
