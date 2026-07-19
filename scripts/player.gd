extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal damaged(amount: int)
signal attack_started(move: int)
signal attack_connected(target: Node, move: int, lethal: bool)
signal guard_changed(active: bool)
signal perfect_guarded(source: Node)
signal guard_broken
signal died

enum AttackPhase { IDLE, WINDUP, ACTIVE, RECOVERY }

const COMBAT := preload("res://scripts/combat_rules.gd")
const CAMERA_SCRIPT := preload("res://scripts/camera_rig.gd")
const SPRITE_LIBRARY := preload("res://scripts/sprite_library.gd")
const SPEED := 122.5
const ACCELERATION := 775.0
const AIR_ACCELERATION := 460.0
const FRICTION := 950.0
const JUMP_SPEED := -292.5
const GRAVITY := 875.0
const DASH_SPEED := 325.0
const MAX_STAMINA := 100.0
const STAMINA_REGEN_RATE := 35.0
const STAMINA_REGEN_DELAY := 0.5
const LIGHT_ONE_COST := 12.0
const LIGHT_TWO_COST := 16.0
const HEAVY_COST := 32.0
const RIPOSTE_COST := 28.0
const DASH_COST := 24.0
const ATTACK_ONE := Vector3(4.0 / 60.0, 5.0 / 60.0, 9.0 / 60.0)
const ATTACK_TWO := Vector3(5.0 / 60.0, 6.0 / 60.0, 12.0 / 60.0)
const HEAVY_ATTACK := Vector3(12.0 / 60.0, 6.0 / 60.0, 20.0 / 60.0)
const RIPOSTE_ATTACK := Vector3(6.0 / 60.0, 5.0 / 60.0, 14.0 / 60.0)
const COMBO_BUFFER_WINDOW := 8.0 / 60.0
const PERFECT_GUARD_WINDOW := 7.0 / 60.0
const RIPOSTE_WINDOW := 0.65

var max_health := 5
var health := 5
var max_stamina := MAX_STAMINA
var stamina := MAX_STAMINA
var facing := 1.0
var coyote_time := 0.0
var jump_buffer := 0.0
var attack_time := 0.0
var attack_phase := AttackPhase.IDLE
var attack_phase_time := 0.0
var attack_move := COMBAT.PlayerMove.LIGHT_ONE
var attack_stage := 0
var combo_queued := false
var dash_time := 0.0
var dash_move_time := 0.0
var invulnerable_time := 0.0
var hurt_time := 0.0
var guard_break_time := 0.0
var perfect_guard_time := 0.0
var perfect_guard_visual_time := 0.0
var riposte_window_time := 0.0
var stamina_regen_delay := 0.0
var guarding := false
var air_dash_used := false
var walk_phase := 0.0
var controls_enabled := true
var dead := false
var attack_area: Area2D
var attack_box: RectangleShape2D
var sprite: AnimatedSprite2D
var attack_hits: Dictionary = {}
var riposte_target: Node2D
var ground_offset := 0.0
var _step_timer := 0.0
var _was_on_floor := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.0
	capsule.height = 23.0
	collider.shape = capsule
	add_child(collider)
	ground_offset = collider.position.y + capsule.height * 0.5
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	attack_area.monitoring = false
	var attack_shape := CollisionShape2D.new()
	attack_box = RectangleShape2D.new()
	attack_box.size = Vector2(32, 24)
	attack_shape.shape = attack_box
	attack_area.add_child(attack_shape)
	attack_area.body_entered.connect(_on_attack_body_entered)
	attack_area.area_entered.connect(_on_attack_area_entered)
	add_child(attack_area)
	_setup_sprite()
	var camera := CAMERA_SCRIPT.new()
	add_child(camera)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	_was_on_floor = is_on_floor()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	dash_time = maxf(dash_time - delta, 0.0)
	dash_move_time = maxf(dash_move_time - delta, 0.0)
	invulnerable_time = maxf(invulnerable_time - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	guard_break_time = maxf(guard_break_time - delta, 0.0)
	perfect_guard_time = maxf(perfect_guard_time - delta, 0.0)
	perfect_guard_visual_time = maxf(perfect_guard_visual_time - delta, 0.0)
	riposte_window_time = maxf(riposte_window_time - delta, 0.0)
	stamina_regen_delay = maxf(stamina_regen_delay - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	_step_timer = maxf(_step_timer - delta, 0.0)
	coyote_time = 0.11 if is_on_floor() else maxf(coyote_time - delta, 0.0)
	_update_attack(delta)
	_update_stamina(delta)

	if guarding and (not controls_enabled or not is_on_floor() or hurt_time > 0.0 or guard_break_time > 0.0):
		stop_guard()
	if controls_enabled and Input.is_action_just_pressed("guard"):
		start_guard()
	if Input.is_action_just_released("guard"):
		stop_guard()
	if controls_enabled and Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13
	if controls_enabled and Input.is_action_just_pressed("attack") and _can_start_attack():
		_handle_attack_input()
	if controls_enabled and Input.is_action_just_pressed("heavy_attack") and _can_start_attack():
		_handle_heavy_input()
	if controls_enabled and Input.is_action_just_pressed("dash"):
		start_dash()

	var falling_speed := velocity.y
	if dash_move_time > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
	else:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if jump_buffer > 0.0 and coyote_time > 0.0 and controls_enabled and _can_jump():
			velocity.y = JUMP_SPEED
			jump_buffer = 0.0
			coyote_time = 0.0
			AudioManager.play_sfx(&"jump", 0.035, -2.0)
		var can_move := controls_enabled and hurt_time <= 0.0 and guard_break_time <= 0.0
		var input_axis := Input.get_axis("move_left", "move_right") if can_move else 0.0
		if absf(input_axis) > 0.05:
			if attack_phase == AttackPhase.IDLE and dash_time <= 0.0:
				facing = signf(input_axis)
			var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
			var speed_scale := 1.0
			if attack_phase != AttackPhase.IDLE:
				speed_scale = 0.42
			elif guarding:
				speed_scale = 0.35
			elif dash_time > 0.0:
				speed_scale = 0.0
			velocity.x = move_toward(velocity.x, input_axis * SPEED * speed_scale, acceleration * delta)
		else:
			var friction := FRICTION if is_on_floor() else AIR_ACCELERATION * 0.45
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	if is_on_floor():
		air_dash_used = false
	if is_on_floor() and not _was_on_floor and falling_speed > 95.0:
		AudioManager.play_sfx(&"land", 0.06, -3.0)
		if falling_speed > 190.0:
			var camera := get_viewport().get_camera_2d()
			if camera and camera.has_method("add_shake"):
				camera.add_shake(1.0)
	_was_on_floor = is_on_floor()
	walk_phase += absf(velocity.x) * delta * 0.07
	if is_on_floor() and absf(velocity.x) > 55.0 and _step_timer <= 0.0 and attack_phase == AttackPhase.IDLE and not guarding:
		AudioManager.play_sfx(&"footstep", 0.08, -10.0)
		_step_timer = 0.28
	if global_position.y > 410.0:
		fall_out()
	modulate.a = 0.42 if invulnerable_time > 0.0 and int(invulnerable_time * 18.0) % 2 == 0 else 1.0
	_update_visual_state()
	queue_redraw()

func _can_start_attack() -> bool:
	return dash_time <= 0.0 and hurt_time <= 0.0 and guard_break_time <= 0.0 and not guarding

func _can_jump() -> bool:
	return hurt_time <= 0.0 and guard_break_time <= 0.0 and dash_time <= 0.0 and not guarding and attack_phase == AttackPhase.IDLE

func _handle_attack_input() -> void:
	if attack_phase == AttackPhase.IDLE:
		_start_attack_move(COMBAT.PlayerMove.LIGHT_ONE)
	elif attack_move == COMBAT.PlayerMove.LIGHT_ONE and attack_phase == AttackPhase.RECOVERY and attack_phase_time <= COMBO_BUFFER_WINDOW:
		combo_queued = true

func _handle_heavy_input() -> void:
	if attack_phase != AttackPhase.IDLE:
		return
	if _can_riposte():
		_start_attack_move(COMBAT.PlayerMove.RIPOSTE)
	else:
		_start_attack_move(COMBAT.PlayerMove.HEAVY)

func _can_riposte() -> bool:
	if riposte_window_time <= 0.0 or not is_instance_valid(riposte_target):
		return false
	if riposte_target.has_method("can_be_riposted") and not bool(riposte_target.can_be_riposted()):
		return false
	var offset := riposte_target.global_position - global_position
	return absf(offset.x) <= 52.0 and absf(offset.y) <= 28.0 and signf(offset.x) == signf(facing)

func _start_attack_move(move: int) -> bool:
	var cost := _stamina_cost_for_move(move)
	if not _spend_stamina(cost):
		return false
	attack_move = move
	attack_stage = 1 if move == COMBAT.PlayerMove.LIGHT_ONE else (2 if move == COMBAT.PlayerMove.LIGHT_TWO else 0)
	attack_phase = AttackPhase.WINDUP
	combo_queued = false
	attack_hits.clear()
	var timing := _timing_for_move(move)
	attack_phase_time = timing.x
	attack_time = timing.x + timing.y + timing.z
	attack_area.set_deferred("monitoring", false)
	_configure_attack_hitbox(move)
	match move:
		COMBAT.PlayerMove.LIGHT_ONE:
			velocity.x = facing * 78.0
			AudioManager.play_sfx(&"swing_1", 0.025, -2.0)
		COMBAT.PlayerMove.LIGHT_TWO:
			velocity.x = facing * 104.0
			AudioManager.play_sfx(&"swing_2", 0.025, -2.0)
		COMBAT.PlayerMove.HEAVY:
			velocity.x = facing * 62.0
			AudioManager.play_sfx(&"heavy_swing", 0.02, -1.0)
		COMBAT.PlayerMove.RIPOSTE:
			velocity.x = facing * 145.0
			riposte_window_time = 0.0
			riposte_target = null
			AudioManager.play_sfx(&"riposte", 0.015, 0.0)
	attack_started.emit(move)
	SPRITE_LIBRARY.play(sprite, _animation_for_move(move), true)
	return true

func _configure_attack_hitbox(move: int) -> void:
	match move:
		COMBAT.PlayerMove.HEAVY:
			attack_box.size = Vector2(40, 27)
			attack_area.position.x = facing * 22.0
		COMBAT.PlayerMove.RIPOSTE:
			attack_box.size = Vector2(46, 24)
			attack_area.position.x = facing * 25.0
		_:
			attack_box.size = Vector2(32, 24)
			attack_area.position.x = facing * 18.5

func _update_attack(delta: float) -> void:
	if attack_phase == AttackPhase.IDLE:
		attack_time = 0.0
		return
	attack_phase_time -= delta
	attack_time = maxf(attack_time - delta, 0.0)
	if attack_phase_time > 0.0:
		return
	var timing := _timing_for_move(attack_move)
	match attack_phase:
		AttackPhase.WINDUP:
			attack_phase = AttackPhase.ACTIVE
			attack_phase_time = timing.y
			attack_area.set_deferred("monitoring", true)
			_check_attack_overlaps.call_deferred()
		AttackPhase.ACTIVE:
			attack_phase = AttackPhase.RECOVERY
			attack_phase_time = timing.z
			attack_area.set_deferred("monitoring", false)
		AttackPhase.RECOVERY:
			if attack_move == COMBAT.PlayerMove.LIGHT_ONE and combo_queued:
				if not _start_attack_move(COMBAT.PlayerMove.LIGHT_TWO):
					_finish_attack()
			else:
				_finish_attack()

func _finish_attack() -> void:
	attack_phase = AttackPhase.IDLE
	attack_stage = 0
	attack_time = 0.0
	combo_queued = false
	attack_area.set_deferred("monitoring", false)

func _timing_for_move(move: int) -> Vector3:
	match move:
		COMBAT.PlayerMove.LIGHT_TWO: return ATTACK_TWO
		COMBAT.PlayerMove.HEAVY: return HEAVY_ATTACK
		COMBAT.PlayerMove.RIPOSTE: return RIPOSTE_ATTACK
	return ATTACK_ONE

func _stamina_cost_for_move(move: int) -> float:
	match move:
		COMBAT.PlayerMove.LIGHT_TWO: return LIGHT_TWO_COST
		COMBAT.PlayerMove.HEAVY: return HEAVY_COST
		COMBAT.PlayerMove.RIPOSTE: return RIPOSTE_COST
	return LIGHT_ONE_COST

func _animation_for_move(move: int) -> StringName:
	match move:
		COMBAT.PlayerMove.LIGHT_TWO: return &"attack_two"
		COMBAT.PlayerMove.HEAVY: return &"heavy_attack"
		COMBAT.PlayerMove.RIPOSTE: return &"riposte"
	return &"attack_one"

func start_attack() -> bool:
	if attack_phase != AttackPhase.IDLE or not _can_start_attack():
		return false
	return _start_attack_move(COMBAT.PlayerMove.LIGHT_ONE)

func start_heavy_attack() -> bool:
	if attack_phase != AttackPhase.IDLE or not _can_start_attack():
		return false
	return _start_attack_move(COMBAT.PlayerMove.HEAVY)

func start_dash() -> bool:
	if dead or not controls_enabled or hurt_time > 0.0 or guard_break_time > 0.0 or dash_time > 0.0 or attack_phase != AttackPhase.IDLE:
		return false
	if not is_on_floor() and air_dash_used:
		return false
	if not _spend_stamina(DASH_COST):
		return false
	stop_guard()
	if not is_on_floor():
		air_dash_used = true
	dash_time = 0.28
	dash_move_time = 0.16
	invulnerable_time = maxf(invulnerable_time, 0.22)
	attack_area.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"dash", 0.04, -2.0)
	InputRouter.vibrate(0.14, 0.22, 0.08)
	SPRITE_LIBRARY.play(sprite, &"dash", true)
	return true

func start_guard() -> bool:
	if dead or not controls_enabled or guarding or not is_on_floor() or attack_phase != AttackPhase.IDLE or dash_time > 0.0 or hurt_time > 0.0 or guard_break_time > 0.0:
		return false
	guarding = true
	perfect_guard_time = PERFECT_GUARD_WINDOW
	velocity.x = 0.0
	guard_changed.emit(true)
	SPRITE_LIBRARY.play(sprite, &"guard", true)
	queue_redraw()
	return true

func stop_guard() -> void:
	if not guarding:
		return
	guarding = false
	perfect_guard_time = 0.0
	guard_changed.emit(false)
	queue_redraw()

func _on_attack_body_entered(body: Node) -> void:
	hit_attack_target(body)

func _on_attack_area_entered(area: Area2D) -> void:
	hit_attack_target(area)

func _check_attack_overlaps() -> void:
	if attack_phase != AttackPhase.ACTIVE or not is_instance_valid(attack_area):
		return
	for body in attack_area.get_overlapping_bodies():
		hit_attack_target(body)
	for area in attack_area.get_overlapping_areas():
		hit_attack_target(area)

func hit_attack_target(target_node: Node) -> void:
	if attack_phase != AttackPhase.ACTIVE:
		return
	if not target_node.has_method("take_combat_damage") and not target_node.has_method("take_damage"):
		return
	var id := target_node.get_instance_id()
	if attack_hits.has(id):
		return
	attack_hits[id] = true
	var damage := 1
	var stagger := 1
	var knockback := Vector2(facing * 165.0, -62.5)
	match attack_move:
		COMBAT.PlayerMove.LIGHT_TWO:
			damage = 2
			knockback = Vector2(facing * 190.0, -70.0)
		COMBAT.PlayerMove.HEAVY:
			damage = 3
			stagger = 4
			knockback = Vector2(facing * 235.0, -92.0)
		COMBAT.PlayerMove.RIPOSTE:
			damage = 5
			stagger = 6
			knockback = Vector2(facing * 285.0, -105.0)
	var lethal := false
	if target_node.has_method("take_combat_damage"):
		lethal = bool(target_node.take_combat_damage(damage, stagger, knockback, attack_move))
	else:
		lethal = bool(target_node.take_damage(damage, knockback))
	attack_connected.emit(target_node, attack_move, lethal)

func receive_combat_hit(hit) -> int:
	if dead or invulnerable_time > 0.0:
		return COMBAT.HitResult.EVADED
	var from_front := true
	if is_instance_valid(hit.source):
		var source_delta: float = hit.source.global_position.x - global_position.x
		from_front = is_zero_approx(source_delta) or signf(source_delta) == signf(facing)
	if guarding and from_front:
		if hit.attack_type == COMBAT.AttackType.NORMAL:
			if perfect_guard_time > 0.0 and stamina >= hit.perfect_guard_cost:
				_spend_stamina(hit.perfect_guard_cost)
				_resolve_perfect_guard(hit.source)
				return COMBAT.HitResult.PERFECT_GUARD
			if stamina >= hit.guard_cost:
				_spend_stamina(hit.guard_cost)
				_resolve_block()
				return COMBAT.HitResult.BLOCKED
			_resolve_guard_break(hit.health_damage, hit.knockback)
			return COMBAT.HitResult.GUARD_BROKEN
		if hit.attack_type == COMBAT.AttackType.YELLOW:
			if perfect_guard_time > 0.0 and stamina >= hit.perfect_guard_cost:
				_spend_stamina(hit.perfect_guard_cost)
				_resolve_perfect_guard(hit.source)
				return COMBAT.HitResult.PERFECT_GUARD
	stop_guard()
	_apply_health_damage(hit.health_damage, hit.knockback, false)
	return COMBAT.HitResult.HIT

func _resolve_block() -> void:
	perfect_guard_time = 0.0
	AudioManager.play_sfx(&"guard_block", 0.02, -2.0)
	FeedbackDirector.request_hit(global_position + Vector2(facing * 8.0, -9.0), false, false, Color("8de4dc"))

func _resolve_perfect_guard(source: Node) -> void:
	perfect_guard_time = 0.0
	perfect_guard_visual_time = 4.0 / 60.0
	AudioManager.play_sfx(&"perfect_guard", 0.01, 1.0)
	FeedbackDirector.request_hit(global_position + Vector2(facing * 9.0, -10.0), false, false, Color("ffe36e"))
	InputRouter.vibrate(0.34, 0.58, 0.1)
	if is_instance_valid(source) and source.has_method("on_parried"):
		source.on_parried(self)
		if source is Node2D:
			riposte_target = source
			riposte_window_time = RIPOSTE_WINDOW
	perfect_guarded.emit(source)

func _resolve_guard_break(amount: int, knockback: Vector2) -> void:
	_set_stamina(0.0)
	stop_guard()
	guard_break_time = 0.75
	AudioManager.play_sfx(&"guard_break", 0.02, 0.0)
	guard_broken.emit()
	_apply_health_damage(amount, knockback, true)

func take_damage(amount: int, knockback := Vector2.ZERO) -> bool:
	if dead or invulnerable_time > 0.0:
		return false
	_apply_health_damage(amount, knockback, false)
	return health <= 0

func _apply_health_damage(amount: int, knockback: Vector2, broken: bool) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	velocity = knockback
	hurt_time = maxf(hurt_time, 0.75 if broken else 0.28)
	invulnerable_time = 0.8
	stop_guard()
	_cancel_attack()
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	AudioManager.play_sfx(&"hurt", 0.04, -1.0)
	SPRITE_LIBRARY.play(sprite, &"hurt", true)
	FeedbackDirector.request_hit(global_position + Vector2(0, -9), health <= 0, true, Color("ff6b6b"))
	if health <= 0:
		die()

func _spend_stamina(amount: float) -> bool:
	if stamina + 0.001 < amount:
		_notify_stamina_empty()
		return false
	_set_stamina(stamina - amount)
	stamina_regen_delay = STAMINA_REGEN_DELAY
	return true

func _set_stamina(value: float) -> void:
	var next_value := clampf(value, 0.0, max_stamina)
	if is_equal_approx(next_value, stamina):
		return
	stamina = next_value
	stamina_changed.emit(stamina, max_stamina)

func _update_stamina(delta: float) -> void:
	if stamina_regen_delay > 0.0 or guarding or attack_phase != AttackPhase.IDLE or dash_time > 0.0 or hurt_time > 0.0 or guard_break_time > 0.0:
		return
	if stamina < max_stamina:
		_set_stamina(stamina + STAMINA_REGEN_RATE * delta)

func _notify_stamina_empty() -> void:
	AudioManager.play_sfx(&"stamina_empty", 0.0, -5.0)
	var game := get_tree().get_first_node_in_group("game")
	if game and game.has_method("on_stamina_empty"):
		game.on_stamina_empty()

func heal(amount: int) -> void:
	if dead:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func restore_for_checkpoint() -> void:
	health = max_health
	_set_stamina(max_stamina)
	health_changed.emit(health, max_health)

func fall_out() -> void:
	if dead:
		return
	health = 0
	health_changed.emit(health, max_health)
	die()

func die() -> void:
	if dead:
		return
	dead = true
	controls_enabled = false
	collision_layer = 0
	collision_mask = 0
	stop_guard()
	_cancel_attack()
	died.emit()
	modulate.a = 1.0
	SPRITE_LIBRARY.play(sprite, &"death", true)

func _cancel_attack() -> void:
	attack_phase = AttackPhase.IDLE
	attack_stage = 0
	attack_time = 0.0
	combo_queued = false
	if is_instance_valid(attack_area):
		attack_area.set_deferred("monitoring", false)

func _setup_sprite() -> void:
	var animations := [
		{"name": &"idle", "frames": 4, "fps": 5.0, "loop": true},
		{"name": &"run", "frames": 6, "fps": 13.0, "loop": true},
		{"name": &"jump", "frames": 4, "fps": 9.0, "loop": false},
		{"name": &"attack_one", "frames": 6, "fps": 22.0, "loop": false},
		{"name": &"attack_two", "frames": 6, "fps": 17.0, "loop": false},
		{"name": &"heavy_attack", "frames": 8, "fps": 12.0, "loop": false},
		{"name": &"guard", "frames": 4, "fps": 10.0, "loop": false},
		{"name": &"perfect_guard", "frames": 4, "fps": 24.0, "loop": false},
		{"name": &"riposte", "frames": 8, "fps": 20.0, "loop": false},
		{"name": &"dash", "frames": 4, "fps": 24.0, "loop": false},
		{"name": &"hurt", "frames": 2, "fps": 8.0, "loop": false},
		{"name": &"death", "frames": 6, "fps": 12.0, "loop": false},
	]
	sprite = SPRITE_LIBRARY.create_animated_sprite("player", animations, 128, 0.52, ground_offset)
	add_child(sprite)
	SPRITE_LIBRARY.play(sprite, &"idle")

func _update_visual_state() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.flip_h = facing < 0.0
	sprite.modulate = Color("ffd3d3") if hurt_time > 0.0 else Color.WHITE
	if dead:
		SPRITE_LIBRARY.play(sprite, &"death")
	elif hurt_time > 0.0 or guard_break_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"hurt")
	elif dash_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"dash")
	elif perfect_guard_visual_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"perfect_guard")
	elif attack_phase != AttackPhase.IDLE:
		SPRITE_LIBRARY.play(sprite, _animation_for_move(attack_move))
	elif guarding:
		SPRITE_LIBRARY.play(sprite, &"guard")
	elif not is_on_floor():
		SPRITE_LIBRARY.play(sprite, &"jump")
	elif absf(velocity.x) > 8.0:
		SPRITE_LIBRARY.play(sprite, &"run")
	else:
		SPRITE_LIBRARY.play(sprite, &"idle")

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, ground_offset + 1), Vector2(-7, ground_offset - 1),
		Vector2(7, ground_offset - 1), Vector2(11, ground_offset + 1),
		Vector2(7, ground_offset + 3), Vector2(-7, ground_offset + 3)
	]), Color(0.02, 0.03, 0.07, 0.38))
	if guarding:
		var arc_center := Vector2(facing * 7.0, ground_offset - 12.0)
		var from_angle := -PI * 0.5 if facing > 0.0 else PI * 0.5
		var to_angle := PI * 0.5 if facing > 0.0 else PI * 1.5
		var color := Color("ffe36e") if perfect_guard_time > 0.0 else Color("8de4dc")
		draw_arc(arc_center, 12.0, from_angle, to_angle, 12, Color(color, 0.9), 2.0)
