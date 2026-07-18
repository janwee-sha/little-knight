extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal attack_started(stage: int)
signal attack_connected(target: Node, stage: int, lethal: bool)
signal died

enum AttackPhase { IDLE, WINDUP, ACTIVE, RECOVERY }

const CAMERA_SCRIPT := preload("res://scripts/camera_rig.gd")
const SPRITE_LIBRARY := preload("res://scripts/sprite_library.gd")
const SPEED := 122.5
const ACCELERATION := 775.0
const AIR_ACCELERATION := 460.0
const FRICTION := 950.0
const JUMP_SPEED := -292.5
const GRAVITY := 875.0
const DASH_SPEED := 325.0
const ATTACK_ONE := Vector3(4.0 / 60.0, 5.0 / 60.0, 9.0 / 60.0)
const ATTACK_TWO := Vector3(5.0 / 60.0, 6.0 / 60.0, 12.0 / 60.0)
const COMBO_BUFFER_WINDOW := 8.0 / 60.0

var max_health := 5
var health := 5
var facing := 1.0
var coyote_time := 0.0
var jump_buffer := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var attack_stage := 0
var attack_phase := AttackPhase.IDLE
var attack_phase_time := 0.0
var combo_queued := false
var dash_time := 0.0
var dash_cooldown := 0.0
var invulnerable_time := 0.0
var hurt_time := 0.0
var walk_phase := 0.0
var controls_enabled := true
var dead := false
var attack_area: Area2D
var sprite: AnimatedSprite2D
var attack_hits: Dictionary = {}
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
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	attack_area.monitoring = false
	var attack_shape := CollisionShape2D.new()
	var slash_box := RectangleShape2D.new()
	slash_box.size = Vector2(32, 24)
	attack_shape.shape = slash_box
	attack_area.add_child(attack_shape)
	attack_area.body_entered.connect(_on_attack_body_entered)
	attack_area.area_entered.connect(_on_attack_area_entered)
	add_child(attack_area)
	_setup_sprite()
	var camera := CAMERA_SCRIPT.new()
	add_child(camera)
	health_changed.emit(health, max_health)
	_was_on_floor = is_on_floor()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	dash_time = maxf(dash_time - delta, 0.0)
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	invulnerable_time = maxf(invulnerable_time - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	_step_timer = maxf(_step_timer - delta, 0.0)
	coyote_time = 0.11 if is_on_floor() else maxf(coyote_time - delta, 0.0)
	_update_attack(delta)

	if controls_enabled and Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13
	if controls_enabled and Input.is_action_just_pressed("attack") and dash_time <= 0.0 and hurt_time <= 0.0:
		_handle_attack_input()
	if controls_enabled and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and hurt_time <= 0.0 and attack_phase == AttackPhase.IDLE:
		start_dash()

	var falling_speed := velocity.y
	if dash_time > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
	else:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if jump_buffer > 0.0 and coyote_time > 0.0 and controls_enabled and hurt_time <= 0.0:
			velocity.y = JUMP_SPEED
			jump_buffer = 0.0
			coyote_time = 0.0
			AudioManager.play_sfx(&"jump", 0.035, -2.0)
		var input_axis := Input.get_axis("move_left", "move_right") if controls_enabled and hurt_time <= 0.0 else 0.0
		if absf(input_axis) > 0.05:
			if attack_phase == AttackPhase.IDLE:
				facing = signf(input_axis)
			var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
			var speed_scale := 0.42 if attack_phase != AttackPhase.IDLE else 1.0
			velocity.x = move_toward(velocity.x, input_axis * SPEED * speed_scale, acceleration * delta)
		else:
			var friction := FRICTION if is_on_floor() else AIR_ACCELERATION * 0.45
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	if is_on_floor() and not _was_on_floor and falling_speed > 95.0:
		AudioManager.play_sfx(&"land", 0.06, -3.0)
		if falling_speed > 190.0:
			var camera := get_viewport().get_camera_2d()
			if camera and camera.has_method("add_shake"):
				camera.add_shake(1.0)
	_was_on_floor = is_on_floor()
	walk_phase += absf(velocity.x) * delta * 0.07
	if is_on_floor() and absf(velocity.x) > 55.0 and _step_timer <= 0.0 and attack_phase == AttackPhase.IDLE:
		AudioManager.play_sfx(&"footstep", 0.08, -10.0)
		_step_timer = 0.28
	if global_position.y > 410.0:
		fall_out()
	attack_area.position.x = facing * 18.5
	modulate.a = 0.42 if invulnerable_time > 0.0 and int(invulnerable_time * 18.0) % 2 == 0 else 1.0
	_update_visual_state()
	queue_redraw()

func _handle_attack_input() -> void:
	if attack_phase == AttackPhase.IDLE:
		_start_attack_stage(1)
	elif attack_stage == 1 and attack_phase == AttackPhase.RECOVERY and attack_phase_time <= COMBO_BUFFER_WINDOW:
		combo_queued = true

func _start_attack_stage(stage: int) -> void:
	attack_stage = stage
	attack_phase = AttackPhase.WINDUP
	combo_queued = false
	attack_hits.clear()
	var timing := ATTACK_ONE if stage == 1 else ATTACK_TWO
	attack_phase_time = timing.x
	attack_time = timing.x + timing.y + timing.z
	attack_cooldown = attack_time
	attack_area.set_deferred("monitoring", false)
	velocity.x = facing * (78.0 if stage == 1 else 104.0)
	AudioManager.play_sfx(&"swing_1" if stage == 1 else &"swing_2", 0.025, -2.0)
	attack_started.emit(stage)
	SPRITE_LIBRARY.play(sprite, &"attack_one" if stage == 1 else &"attack_two", true)

func _update_attack(delta: float) -> void:
	if attack_phase == AttackPhase.IDLE:
		attack_time = 0.0
		attack_cooldown = 0.0
		return
	attack_phase_time -= delta
	attack_time = maxf(attack_time - delta, 0.0)
	attack_cooldown = attack_time
	if attack_phase_time > 0.0:
		return
	var timing := ATTACK_ONE if attack_stage == 1 else ATTACK_TWO
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
			if attack_stage == 1 and combo_queued:
				_start_attack_stage(2)
			else:
				attack_phase = AttackPhase.IDLE
				attack_stage = 0
				attack_time = 0.0
				attack_cooldown = 0.0
				combo_queued = false
				attack_area.set_deferred("monitoring", false)

func start_attack() -> void:
	if attack_phase == AttackPhase.IDLE:
		_start_attack_stage(1)

func start_dash() -> void:
	dash_time = 0.16
	dash_cooldown = 0.72
	invulnerable_time = 0.22
	attack_area.set_deferred("monitoring", false)
	AudioManager.play_sfx(&"dash", 0.04, -2.0)
	InputRouter.vibrate(0.14, 0.22, 0.08)
	SPRITE_LIBRARY.play(sprite, &"dash", true)

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
	if attack_phase != AttackPhase.ACTIVE or not target_node.has_method("take_damage"):
		return
	var id := target_node.get_instance_id()
	if attack_hits.has(id):
		return
	attack_hits[id] = true
	var lethal := bool(target_node.take_damage(1, Vector2(facing * 165.0, -62.5)))
	attack_connected.emit(target_node, attack_stage, lethal)

func take_damage(amount: int, knockback := Vector2.ZERO) -> bool:
	if dead or invulnerable_time > 0.0 or dash_time > 0.0:
		return false
	health = maxi(health - amount, 0)
	velocity = knockback
	hurt_time = 0.28
	invulnerable_time = 1.0
	_cancel_attack()
	health_changed.emit(health, max_health)
	damaged.emit(amount)
	AudioManager.play_sfx(&"hurt", 0.04, -1.0)
	SPRITE_LIBRARY.play(sprite, &"hurt", true)
	FeedbackDirector.request_hit(global_position + Vector2(0, -9), health <= 0, true, Color("ff6b6b"))
	if health <= 0:
		die()
	return health <= 0

func heal(amount: int) -> void:
	if dead:
		return
	health = mini(health + amount, max_health)
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
	_cancel_attack()
	died.emit()
	modulate.a = 1.0
	SPRITE_LIBRARY.play(sprite, &"death", true)

func _cancel_attack() -> void:
	attack_phase = AttackPhase.IDLE
	attack_stage = 0
	attack_time = 0.0
	attack_cooldown = 0.0
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
		{"name": &"dash", "frames": 4, "fps": 24.0, "loop": false},
		{"name": &"hurt", "frames": 2, "fps": 8.0, "loop": false},
		{"name": &"death", "frames": 6, "fps": 12.0, "loop": false},
	]
	sprite = SPRITE_LIBRARY.create_animated_sprite("player", animations)
	add_child(sprite)
	SPRITE_LIBRARY.play(sprite, &"idle")


func _update_visual_state() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.flip_h = facing < 0.0
	sprite.modulate = Color("ffd3d3") if hurt_time > 0.0 else Color.WHITE
	if dead:
		SPRITE_LIBRARY.play(sprite, &"death")
	elif hurt_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"hurt")
	elif dash_time > 0.0:
		SPRITE_LIBRARY.play(sprite, &"dash")
	elif attack_phase != AttackPhase.IDLE:
		SPRITE_LIBRARY.play(sprite, &"attack_one" if attack_stage == 1 else &"attack_two")
	elif not is_on_floor():
		SPRITE_LIBRARY.play(sprite, &"jump")
	elif absf(velocity.x) > 8.0:
		SPRITE_LIBRARY.play(sprite, &"run")
	else:
		SPRITE_LIBRARY.play(sprite, &"idle")


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 1), Vector2(-7, -1), Vector2(7, -1), Vector2(11, 1),
		Vector2(7, 3), Vector2(-7, 3)
	]), Color(0.02, 0.03, 0.07, 0.38))
