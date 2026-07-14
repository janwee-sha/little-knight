extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

const SPEED := 245.0
const ACCELERATION := 1550.0
const AIR_ACCELERATION := 920.0
const FRICTION := 1900.0
const JUMP_SPEED := -585.0
const GRAVITY := 1750.0
const DASH_SPEED := 650.0

var max_health := 5
var health := 5
var facing := 1.0
var coyote_time := 0.0
var jump_buffer := 0.0
var attack_time := 0.0
var attack_cooldown := 0.0
var dash_time := 0.0
var dash_cooldown := 0.0
var invulnerable_time := 0.0
var hurt_time := 0.0
var walk_phase := 0.0
var controls_enabled := true
var dead := false
var attack_area: Area2D
var attack_hits: Dictionary = {}

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14.0
	capsule.height = 46.0
	collider.shape = capsule
	add_child(collider)
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 4
	attack_area.monitoring = false
	var attack_shape := CollisionShape2D.new()
	var slash_box := RectangleShape2D.new()
	slash_box.size = Vector2(58, 48)
	attack_shape.shape = slash_box
	attack_area.add_child(attack_shape)
	attack_area.body_entered.connect(_on_attack_body_entered)
	attack_area.area_entered.connect(_on_attack_area_entered)
	add_child(attack_area)
	var camera := Camera2D.new()
	camera.position = Vector2(180, -70)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_right = 5600
	camera.limit_top = 0
	camera.limit_bottom = 720
	add_child(camera)
	health_changed.emit(health, max_health)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_time = maxf(attack_time - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	dash_time = maxf(dash_time - delta, 0.0)
	dash_cooldown = maxf(dash_cooldown - delta, 0.0)
	invulnerable_time = maxf(invulnerable_time - delta, 0.0)
	hurt_time = maxf(hurt_time - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	coyote_time = 0.11 if is_on_floor() else maxf(coyote_time - delta, 0.0)

	if controls_enabled and Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13
	if controls_enabled and Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0 and dash_time <= 0.0:
		start_attack()
	if controls_enabled and Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0 and hurt_time <= 0.0:
		start_dash()

	if dash_time > 0.0:
		velocity = Vector2(facing * DASH_SPEED, 0.0)
	else:
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		if jump_buffer > 0.0 and coyote_time > 0.0 and controls_enabled:
			velocity.y = JUMP_SPEED
			jump_buffer = 0.0
			coyote_time = 0.0
		var input_axis := Input.get_axis("move_left", "move_right") if controls_enabled and hurt_time <= 0.0 else 0.0
		if absf(input_axis) > 0.05:
			facing = signf(input_axis)
			var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
			velocity.x = move_toward(velocity.x, input_axis * SPEED, acceleration * delta)
		else:
			var friction := FRICTION if is_on_floor() else AIR_ACCELERATION * 0.45
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	walk_phase += absf(velocity.x) * delta * 0.035
	if global_position.y > 820.0:
		fall_out()
	attack_area.position.x = facing * 37.0
	queue_redraw()

func start_attack() -> void:
	attack_time = 0.24
	attack_cooldown = 0.34
	attack_hits.clear()
	attack_area.set_deferred("monitoring", true)
	get_tree().create_timer(0.13).timeout.connect(_finish_attack)

func _finish_attack() -> void:
	if is_instance_valid(attack_area):
		attack_area.set_deferred("monitoring", false)

func start_dash() -> void:
	dash_time = 0.16
	dash_cooldown = 0.72
	invulnerable_time = 0.22
	attack_area.set_deferred("monitoring", false)

func _on_attack_body_entered(body: Node) -> void:
	hit_attack_target(body)

func _on_attack_area_entered(area: Area2D) -> void:
	hit_attack_target(area)

func hit_attack_target(target_node: Node) -> void:
	if attack_time <= 0.0 or not target_node.has_method("take_damage"):
		return
	var id := target_node.get_instance_id()
	if attack_hits.has(id):
		return
	attack_hits[id] = true
	target_node.take_damage(1, Vector2(facing * 330.0, -125.0))

func take_damage(amount: int, knockback := Vector2.ZERO) -> void:
	if dead or invulnerable_time > 0.0 or dash_time > 0.0:
		return
	health = maxi(health - amount, 0)
	velocity = knockback
	hurt_time = 0.28
	invulnerable_time = 1.0
	health_changed.emit(health, max_health)
	if health <= 0:
		die()

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
	attack_area.set_deferred("monitoring", false)
	died.emit()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", -facing * 1.2, 0.4)
	tween.tween_property(self, "modulate:a", 0.15, 0.55)

func _draw() -> void:
	var blinking := invulnerable_time > 0.0 and int(invulnerable_time * 18.0) % 2 == 0
	if blinking:
		modulate.a = 0.45
	else:
		modulate.a = 1.0
	var bob := sin(walk_phase) * 2.2 if absf(velocity.x) > 12.0 and is_on_floor() else 0.0
	# Shadow and cape.
	draw_oval(Vector2(0, 24), Vector2(23, 6), Color(0.04, 0.05, 0.1, 0.3))
	var cape_points := PackedVector2Array([Vector2(-facing * 7, -12), Vector2(-facing * 23, 16), Vector2(-facing * 5, 18)])
	draw_colored_polygon(cape_points, Color("d1495b"))
	# Boots, tunic, belt.
	draw_rect(Rect2(-13, 14 + bob, 10, 10), Color("302b3c"))
	draw_rect(Rect2(3, 14 - bob, 10, 10), Color("302b3c"))
	draw_rect(Rect2(-16, -10, 32, 30), Color("486b8a"))
	draw_rect(Rect2(-17, 6, 34, 6), Color("2d3142"))
	draw_rect(Rect2(-3, 5, 7, 8), Color("f6bd60"))
	# Helmet with a tiny feather and eye slit.
	draw_circle(Vector2(0, -16), 21.0, Color("c9d6df"))
	draw_polygon(PackedVector2Array([Vector2(-18,-17), Vector2(0,-36), Vector2(18,-17)]), PackedColorArray([Color("e2eaf0")]))
	draw_line(Vector2(0, -36), Vector2(10 * facing, -48), Color("d1495b"), 5.0)
	draw_rect(Rect2(-15, -20, 30, 10), Color("3d405b"))
	draw_circle(Vector2(7 * facing, -15), 2.5, Color("90f1ef"))
	# Sword animation.
	var hand := Vector2(14 * facing, 1)
	var sword_angle := (-1.0 if facing > 0 else PI + 1.0)
	if attack_time > 0.0:
		var progress := 1.0 - attack_time / 0.24
		sword_angle = lerpf(-1.45, 0.75, progress) if facing > 0 else lerpf(PI + 1.45, PI - 0.75, progress)
	var sword_tip := hand + Vector2.from_angle(sword_angle) * 42.0
	draw_line(hand, sword_tip, Color("edf6f9"), 6.0)
	draw_line(hand, sword_tip, Color("a9def9"), 2.0)
	draw_line(hand + Vector2(-4, -4), hand + Vector2(5, 5), Color("f6bd60"), 5.0)
	if dash_time > 0.0:
		for i in 3:
			draw_line(Vector2(-facing * (25 + i * 15), -12 + i * 12), Vector2(-facing * (55 + i * 17), -12 + i * 12), Color(0.56, 0.95, 0.94, 0.65 - i * 0.15), 4.0)

func draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
