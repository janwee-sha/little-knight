extends SceneTree

const COMBAT := preload("res://scripts/combat_rules.gd")

var game: Node2D
var run_state: Node
var feedback_director: Node
var failures: Array[String] = []

func _initialize() -> void:
	run_state = root.get_node("RunState")
	feedback_director = root.get_node("FeedbackDirector")
	run_state.reset_run()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(game)
	run_checks.call_deferred()

func run_checks() -> void:
	await process_frame
	await process_frame
	for _frame in 30:
		await physics_frame
	check(is_instance_valid(game.player), "Player should be created")
	check(game.enemies_total == 8, "All encounters should be counted")
	check(game.enemies_left == 8, "Enemy counter should start full")
	check(game.has_node("BackdropLayer/MoonlitRuins"), "Imported moonlit ruins backdrop should be mounted")
	check(get_root().content_scale_size == Vector2i(640, 360), "Viewport should use the 640x360 pixel-art baseline")
	check(InputMap.action_get_deadzone("move_left") == 0.25, "Movement deadzone should be 0.25")
	check(has_key(&"move_left", KEY_A) and has_key(&"move_left", KEY_LEFT), "Keyboard movement mappings should exist")
	check(has_mouse_button(&"attack", MOUSE_BUTTON_LEFT), "Left mouse should attack")
	check(has_mouse_button(&"heavy_attack", MOUSE_BUTTON_MIDDLE), "Middle mouse should heavy attack")
	check(has_mouse_button(&"guard", MOUSE_BUTTON_RIGHT), "Right mouse should guard")
	check(has_key(&"dash", KEY_SHIFT) and has_key(&"dash", KEY_X), "Keyboard dodge mappings should exist")
	check(has_joy_button(&"jump", JOY_BUTTON_A), "Gamepad south button should jump")
	check(has_joy_button(&"attack", JOY_BUTTON_X), "Gamepad west button should attack")
	check(has_joy_button(&"heavy_attack", JOY_BUTTON_Y), "Gamepad north button should heavy attack")
	check(has_joy_button(&"guard", JOY_BUTTON_LEFT_SHOULDER), "Gamepad left shoulder should guard")
	check(has_joy_button(&"dash", JOY_BUTTON_B), "Gamepad east button should dash")
	check(has_joy_button(&"move_left", JOY_BUTTON_DPAD_LEFT), "D-pad movement should exist")
	check(has_joy_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0), "Left stick should move left")
	check(has_joy_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0), "Left stick should move right")
	check(has_joy_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0), "Left stick should navigate menus")
	check(has_joy_button(&"pause", JOY_BUTTON_START), "Gamepad menu button should pause")
	check(has_joy_button(&"restart", JOY_BUTTON_START), "Gamepad menu button should restart from terminal screens")

	var knight: CharacterBody2D = game.player
	check(is_instance_valid(knight.sprite), "Player should use an AnimatedSprite2D renderer")
	for animation in [&"idle", &"run", &"jump", &"attack_one", &"attack_two", &"heavy_attack", &"guard", &"perfect_guard", &"riposte", &"dash", &"hurt", &"death"]:
		check(knight.sprite.sprite_frames.has_animation(animation), "Player animation should exist: %s" % animation)
	check_sprite_grounding(knight, "Player")
	check_runtime_frames(knight.sprite, "Player")
	check_scale_match(knight.sprite, &"idle", 0, &"attack_one", 0, "Player attack one")
	check_scale_match(knight.sprite, &"idle", 0, &"attack_two", 5, "Player attack two")
	for animation in [&"heavy_attack", &"guard", &"perfect_guard", &"riposte"]:
		check_animation_bounds(knight.sprite, animation, "Player %s" % animation)

	var initial_health: int = knight.health
	var initial_stamina: float = knight.stamina
	knight.start_dash()
	check(is_equal_approx(knight.stamina, initial_stamina - 24.0), "Dash should cost 24 stamina")
	knight.take_damage(1, Vector2.ZERO)
	check(knight.health == initial_health, "Dash should grant invulnerability")
	knight.invulnerable_time = 0.0
	knight.take_damage(1, Vector2.ZERO)
	check(knight.health == initial_health - 1, "The dodge action tail should be vulnerable after its 0.22 second i-frame window")
	reset_knight(knight)
	knight.take_damage(1, Vector2.ZERO)
	check(knight.health == initial_health - 1, "Damage should reduce health")
	knight.heal(1)
	check(knight.health == initial_health, "Healing should restore health")

	reset_knight(knight)
	knight.start_attack()
	check(is_equal_approx(knight.stamina, knight.max_stamina - 12.0), "Light attack one should cost 12 stamina")
	check(knight.attack_stage == 1 and knight.attack_phase == knight.AttackPhase.WINDUP, "Attack should begin with stage-one windup")
	knight.attack_phase = knight.AttackPhase.RECOVERY
	knight.attack_phase_time = 0.1
	knight._handle_attack_input()
	check(knight.combo_queued, "Second attack should buffer during the final recovery window")
	knight._update_attack(0.11)
	check(knight.attack_stage == 2 and knight.attack_phase == knight.AttackPhase.WINDUP, "Buffered input should start stage two")
	check(is_equal_approx(knight.stamina, knight.max_stamina - 28.0), "Second light attack should cost another 16 stamina")
	reset_knight(knight)
	knight.start_heavy_attack()
	check(knight.attack_move == COMBAT.PlayerMove.HEAVY, "Heavy input should start the heavy move")
	check(is_equal_approx(knight.stamina, knight.max_stamina - 32.0), "Heavy attack should cost 32 stamina")
	reset_knight(knight)
	knight.stamina = 0.0
	check(not knight.start_heavy_attack(), "Unaffordable heavy attack should be rejected")
	knight.stamina_regen_delay = 0.0
	knight._update_stamina(1.0)
	check(is_equal_approx(knight.stamina, 35.0), "Neutral stamina should regenerate at 35 per second")
	reset_knight(knight)

	var melee_enemy: CharacterBody2D
	var ranged_enemy: CharacterBody2D
	for child in game.get_children():
		if child is CharacterBody2D and child != knight:
			if child.kind == child.Kind.MELEE and not is_instance_valid(melee_enemy):
				melee_enemy = child
			elif child.kind == child.Kind.RANGED and not is_instance_valid(ranged_enemy):
				ranged_enemy = child
	check(is_instance_valid(melee_enemy), "A melee enemy should be available")
	check(is_instance_valid(ranged_enemy), "A ranged enemy should be available")
	if is_instance_valid(melee_enemy):
		check(melee_enemy.max_health == 8 and melee_enemy.max_poise == 4, "Melee guards should use hard health and poise")
		check_sprite_grounding(melee_enemy, "Melee guard")
		check_runtime_frames(melee_enemy.sprite, "Melee guard")
		for animation in [&"attack_yellow", &"attack_red"]:
			check(melee_enemy.sprite.sprite_frames.has_animation(animation), "Melee animation should exist: %s" % animation)
			check_animation_bounds(melee_enemy.sprite, animation, "Melee %s" % animation)
	if is_instance_valid(ranged_enemy):
		check(ranged_enemy.max_health == 5 and ranged_enemy.max_poise == 3, "Ranged guards should use hard health and poise")
		check_sprite_grounding(ranged_enemy, "Ranged guard")
		check_runtime_frames(ranged_enemy.sprite, "Ranged guard")
		check(ranged_enemy.sprite.sprite_frames.has_animation(&"attack_red"), "Ranged red cast animation should exist")
		check_animation_bounds(ranged_enemy.sprite, &"attack_red", "Ranged red cast")

	if is_instance_valid(melee_enemy):
		melee_enemy.global_position = knight.global_position + Vector2(20, 0)
		melee_enemy.encounter_active = true
		var health_before_contact: int = knight.health
		melee_enemy._start_melee_attack(knight.global_position - melee_enemy.global_position, COMBAT.AttackType.NORMAL, false)
		check(melee_enemy.attack_state == melee_enemy.AttackState.WINDUP, "Melee enemies should telegraph before attacking")
		check(knight.health == health_before_contact, "Enemy contact alone should not deal damage")
		test_guard_rules(knight, melee_enemy)
		reset_knight(knight)
		melee_enemy._cancel_attack()
		melee_enemy._start_melee_attack(Vector2(-20, 0), COMBAT.AttackType.YELLOW, false)
		check(melee_enemy.current_attack_type == COMBAT.AttackType.YELLOW, "Yellow attack should retain its type")
		melee_enemy._start_melee_attack(Vector2(-45, 0), COMBAT.AttackType.RED, false)
		check(melee_enemy.current_attack_type == COMBAT.AttackType.RED and melee_enemy.attack_box.size.x == 50.0, "Red attack should use its long hitbox")

	game.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, COMBAT.AttackType.NORMAL)
	var normal_projectile: Area2D = game.get_child(game.get_child_count() - 1)
	normal_projectile.take_damage(1)
	check(not normal_projectile.active, "Normal projectiles should be destructible")
	game.spawn_projectile(Vector2.ZERO, Vector2.RIGHT, COMBAT.AttackType.RED)
	var red_projectile: Area2D = game.get_child(game.get_child_count() - 1)
	red_projectile.take_damage(1)
	check(red_projectile.active and is_equal_approx(red_projectile.velocity.length(), 230.0), "Red projectiles should be fast and indestructible")
	normal_projectile.free()
	red_projectile.free()

	game.pause_game()
	check(paused and game.pause_menu.visible, "Pause should stop the scene tree and show the menu")
	game.resume_game()
	check(not paused and not game.pause_menu.visible, "Resume should restore gameplay and hide the menu")

	for path in [
		"res://assets/audio/ui_confirm.ogg", "res://assets/audio/footstep_1.ogg",
		"res://assets/audio/swing_1.ogg", "res://assets/audio/hit_1.ogg",
		"res://assets/audio/ambience_wind.mp3", "res://assets/fonts/fusion-pixel-12px-proportional.ttf",
		"res://assets/backgrounds/moonlit_ruins.png",
		"res://assets/sprites/runtime/player/heavy_attack/08.png",
		"res://assets/sprites/runtime/player/guard/04.png",
		"res://assets/sprites/runtime/player/perfect_guard/04.png",
		"res://assets/sprites/runtime/player/riposte/08.png",
		"res://assets/sprites/runtime/melee_guard/attack_yellow/08.png",
		"res://assets/sprites/runtime/melee_guard/attack_red/08.png",
		"res://assets/sprites/runtime/ranged_guard/attack_red/08.png",
		"res://assets/sprites/runtime/projectile/flight/04.png"
	]:
		check(FileAccess.file_exists(path), "Required asset should exist: %s" % path)

	game._on_goal_entered(knight)
	check(not game.game_over, "Locked gate should not end the game")
	game.enemies_left = 0
	game._on_goal_entered(knight)
	check(game.game_over and game.won, "Cleared gate should complete the game")
	game.game_over = false
	game.won = false
	var shrine: Area2D
	for child in game.get_children():
		if child is Area2D and child.has_meta("used"):
			shrine = child
			break
	check(is_instance_valid(shrine), "Healing shrine should exist")
	if is_instance_valid(shrine):
		shrine.set_meta("used", false)
		game._on_shrine_entered(knight, shrine)
		check(run_state.has_shrine_checkpoint(), "Shrine should activate the midpoint checkpoint")
		game.queue_free()
		await process_frame
		game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		await process_frame
		await process_frame
		check(is_equal_approx(game.player.position.x, 1495.0), "Checkpoint retries should spawn at the moonlit shrine")
		check(game.enemies_total == 8 and game.enemies_left == 4, "Checkpoint retries should preserve the four cleared first-half guards")

	await cleanup_and_finish()

func test_guard_rules(knight: CharacterBody2D, enemy: CharacterBody2D) -> void:
	feedback_director.reset()
	reset_knight(knight)
	enemy.global_position = knight.global_position + Vector2(20, 0)
	knight.facing = 1.0
	knight.start_guard()
	knight.perfect_guard_time = 0.0
	var normal_hit := COMBAT.HitData.new(COMBAT.AttackType.NORMAL, 2, 18.0, 22.0, Vector2.ZERO, enemy)
	var health_before: int = knight.health
	var result := int(knight.receive_combat_hit(normal_hit))
	check(result == COMBAT.HitResult.BLOCKED and knight.health == health_before, "Normal attacks should be blockable from the front")
	check(is_equal_approx(knight.stamina, knight.max_stamina - 18.0), "Normal block should cost 18 stamina")

	reset_knight(knight)
	knight.start_guard()
	knight.perfect_guard_time = 0.0
	var yellow_hit := COMBAT.HitData.new(COMBAT.AttackType.YELLOW, 2, 0.0, 28.0, Vector2.ZERO, enemy)
	result = int(knight.receive_combat_hit(yellow_hit))
	check(result == COMBAT.HitResult.HIT and knight.health == knight.max_health - 2, "Late guard should not block yellow attacks")

	reset_knight(knight)
	enemy.hurt_time = 0.0
	enemy.parried_time = 0.0
	knight.start_guard()
	result = int(knight.receive_combat_hit(yellow_hit))
	check(result == COMBAT.HitResult.PERFECT_GUARD and knight.health == knight.max_health, "Timed guard should stop yellow attacks")
	check(is_equal_approx(knight.stamina, knight.max_stamina - 28.0), "Yellow perfect guard should cost 28 stamina")
	check(knight.riposte_window_time > 0.0 and enemy.can_be_riposted(), "Perfect guard should open a riposte window")
	knight.stop_guard()
	knight._handle_heavy_input()
	check(knight.attack_move == COMBAT.PlayerMove.RIPOSTE, "Heavy input during the window should start riposte")

	reset_knight(knight)
	knight.start_guard()
	var red_hit := COMBAT.HitData.new(COMBAT.AttackType.RED, 3, 0.0, 0.0, Vector2.ZERO, enemy)
	result = int(knight.receive_combat_hit(red_hit))
	check(result == COMBAT.HitResult.HIT and knight.health == knight.max_health - 3, "Red attacks should bypass guard")

	reset_knight(knight)
	enemy.global_position = knight.global_position + Vector2(-20, 0)
	knight.start_guard()
	knight.perfect_guard_time = 0.0
	result = int(knight.receive_combat_hit(normal_hit))
	check(result == COMBAT.HitResult.HIT, "Attacks from behind should bypass directional guard")

	reset_knight(knight)
	enemy.global_position = knight.global_position + Vector2(20, 0)
	knight.stamina = 10.0
	knight.start_guard()
	knight.perfect_guard_time = 0.0
	result = int(knight.receive_combat_hit(normal_hit))
	check(result == COMBAT.HitResult.GUARD_BROKEN and knight.stamina == 0.0, "Insufficient stamina should cause guard break")
	feedback_director.reset()

func reset_knight(knight: CharacterBody2D) -> void:
	knight._cancel_attack()
	knight.stop_guard()
	knight.health = knight.max_health
	knight.stamina = knight.max_stamina
	knight.hurt_time = 0.0
	knight.guard_break_time = 0.0
	knight.invulnerable_time = 0.0
	knight.dash_time = 0.0
	knight.dash_move_time = 0.0
	knight.riposte_window_time = 0.0
	knight.riposte_target = null
	knight.stamina_regen_delay = 0.0
	knight.controls_enabled = true
	knight.dead = false
	knight.collision_layer = 2
	knight.collision_mask = 1 | 4

func cleanup_and_finish() -> void:
	feedback_director.reset()
	var audio := root.get_node_or_null("AudioManager")
	paused = true
	if audio:
		audio.release_for_shutdown()
	await create_timer(0.15, true, false, true).timeout
	for transient in get_nodes_in_group("transient_feedback"):
		transient.queue_free()
	if is_instance_valid(game):
		game.queue_free()
	game = null
	paused = false
	run_state.reset_run()
	await process_frame
	await process_frame
	finish.call_deferred()

func finish() -> void:
	if failures.is_empty():
		print("Little Knight combat smoke test: PASS")
		quit(0)
	else:
		push_error("Little Knight combat smoke test: %d failure(s)" % failures.size())
		for failure in failures:
			push_error(" - " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func check_sprite_grounding(actor: Node, label: String) -> void:
	var collider: CollisionShape2D
	for child in actor.get_children():
		if child is CollisionShape2D and child.shape is CapsuleShape2D:
			collider = child
			break
	check(is_instance_valid(collider), "%s should have a capsule collider" % label)
	if not is_instance_valid(collider):
		return
	var texture: Texture2D = actor.sprite.sprite_frames.get_frame_texture(&"idle", 0)
	var sprite_bottom: float = actor.sprite.position.y + float(texture.get_height()) * actor.sprite.scale.y * 0.5
	var capsule := collider.shape as CapsuleShape2D
	var collider_bottom := collider.position.y + capsule.height * 0.5
	check(absf(sprite_bottom - collider_bottom) <= 0.01, "%s sprite baseline should match its collider bottom" % label)

func check_runtime_frames(sprite: AnimatedSprite2D, label: String) -> void:
	for animation in sprite.sprite_frames.get_animation_names():
		var frame_count := sprite.sprite_frames.get_frame_count(animation)
		for frame_index in frame_count:
			var texture := sprite.sprite_frames.get_frame_texture(animation, frame_index)
			check(texture.get_size() == Vector2(128, 128), "%s %s frame %d should use a 128x128 runtime canvas" % [label, animation, frame_index + 1])
			var bounds := alpha_bounds(texture)
			check(bounds.position.y + bounds.size.y == 128, "%s %s frame %d should preserve the bottom anchor" % [label, animation, frame_index + 1])

func check_animation_bounds(sprite: AnimatedSprite2D, animation: StringName, label: String) -> void:
	for frame_index in sprite.sprite_frames.get_frame_count(animation):
		var bounds := alpha_bounds(sprite.sprite_frames.get_frame_texture(animation, frame_index))
		check(bounds.size.x > 0 and bounds.size.y >= 35 and bounds.size.y <= 80, "%s frame %d should have plausible visible bounds" % [label, frame_index + 1])

func check_scale_match(sprite: AnimatedSprite2D, reference_animation: StringName, reference_frame: int, candidate_animation: StringName, candidate_frame: int, label: String) -> void:
	var reference := sprite.sprite_frames.get_frame_texture(reference_animation, reference_frame)
	var candidate := sprite.sprite_frames.get_frame_texture(candidate_animation, candidate_frame)
	var reference_height := alpha_bounds(reference).size.y
	var candidate_height := alpha_bounds(candidate).size.y
	check(absi(reference_height - candidate_height) <= 2, "%s calibration height should stay within 2 pixels of idle (%d vs %d)" % [label, candidate_height, reference_height])

func alpha_bounds(texture: Texture2D) -> Rect2i:
	var image := texture.get_image()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.03:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func has_key(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false

func has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func has_joy_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false

func has_joy_axis(action: StringName, axis: JoyAxis, direction: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(signf(event.axis_value), signf(direction)):
			return true
	return false
