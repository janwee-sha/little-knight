extends SceneTree

var game: Node2D
var failures: Array[String] = []

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(game)
	run_checks.call_deferred()

func run_checks() -> void:
	await process_frame
	await process_frame
	check(is_instance_valid(game.player), "Player should be created")
	check(game.enemies_total == 8, "All encounters should be created")
	check(game.enemies_left == 8, "Enemy counter should start full")
	check(game.has_node("BackdropLayer/MoonlitRuins"), "Imported moonlit ruins backdrop should be mounted")
	check(get_root().content_scale_size == Vector2i(640, 360), "Viewport should use the 640x360 pixel-art baseline")
	check(InputMap.action_get_deadzone("move_left") == 0.25, "Movement deadzone should be 0.25")
	check(has_key("move_left", KEY_A) and has_key("move_left", KEY_LEFT), "Keyboard movement mappings should exist")
	check(has_mouse_button("attack", MOUSE_BUTTON_LEFT), "Left mouse should attack")
	check(has_mouse_button("dash", MOUSE_BUTTON_RIGHT), "Right mouse should dash")
	check(has_joy_button("jump", JOY_BUTTON_A), "Gamepad south button should jump")
	check(has_joy_button("attack", JOY_BUTTON_X), "Gamepad west button should attack")
	check(has_joy_button("dash", JOY_BUTTON_B), "Gamepad east button should dash")
	check(has_joy_button("move_left", JOY_BUTTON_DPAD_LEFT), "D-pad movement should exist")
	check(has_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0), "Left stick should move left")
	check(has_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0), "Left stick should move right")
	check(has_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0), "Left stick should navigate menus")
	check(has_joy_button("pause", JOY_BUTTON_START), "Gamepad menu button should pause")

	var knight: CharacterBody2D = game.player
	check(is_instance_valid(knight.sprite), "Player should use an AnimatedSprite2D renderer")
	for animation in [&"idle", &"run", &"jump", &"attack_one", &"attack_two", &"dash", &"hurt", &"death"]:
		check(knight.sprite.sprite_frames.has_animation(animation), "Player animation should exist: %s" % animation)
	var initial_health: int = knight.health
	knight.start_dash()
	knight.take_damage(1, Vector2.ZERO)
	check(knight.health == initial_health, "Dash should grant invulnerability")
	knight.dash_time = 0.0
	knight.invulnerable_time = 0.0
	knight.take_damage(1, Vector2.ZERO)
	check(knight.health == initial_health - 1, "Damage should reduce health")
	knight.heal(1)
	check(knight.health == initial_health, "Healing should restore health")

	knight.hurt_time = 0.0
	knight.invulnerable_time = 0.0
	knight.start_attack()
	check(knight.attack_stage == 1 and knight.attack_phase == knight.AttackPhase.WINDUP, "Attack should begin with stage-one windup")
	knight.attack_phase = knight.AttackPhase.RECOVERY
	knight.attack_phase_time = 0.1
	knight._handle_attack_input()
	check(knight.combo_queued, "Second attack should buffer during the final recovery window")
	knight._update_attack(0.11)
	check(knight.attack_stage == 2 and knight.attack_phase == knight.AttackPhase.WINDUP, "Buffered input should start stage two")

	var first_enemy: CharacterBody2D
	for child in game.get_children():
		if child is CharacterBody2D and child != knight:
			first_enemy = child
			break
	check(is_instance_valid(first_enemy), "An enemy should be available for combat checks")
	if is_instance_valid(first_enemy):
		check(is_instance_valid(first_enemy.sprite), "Enemies should use AnimatedSprite2D renderers")
		var health_before_contact: int = knight.health
		first_enemy.global_position = knight.global_position + Vector2(20, 0)
		first_enemy.attack_cooldown = 0.0
		first_enemy.attack_state = first_enemy.AttackState.NONE
		first_enemy._update_melee(knight.global_position - first_enemy.global_position, 20.0, 0.016)
		check(first_enemy.attack_state == first_enemy.AttackState.WINDUP, "Melee enemies should telegraph before attacking")
		check(knight.health == health_before_contact, "Enemy contact alone should not deal damage")

	game.pause_game()
	check(paused and game.pause_menu.visible, "Pause should stop the scene tree and show the menu")
	game.resume_game()
	check(not paused and not game.pause_menu.visible, "Resume should restore gameplay and hide the menu")

	for path in [
		"res://assets/audio/ui_confirm.ogg", "res://assets/audio/footstep_1.ogg",
		"res://assets/audio/swing_1.ogg", "res://assets/audio/hit_1.ogg",
		"res://assets/audio/ambience_wind.mp3", "res://assets/fonts/fusion-pixel-12px-proportional.ttf",
		"res://assets/backgrounds/moonlit_ruins.png",
		"res://assets/sprites/runtime/player/attack_two/06.png",
		"res://assets/sprites/runtime/melee_guard/attack/06.png",
		"res://assets/sprites/runtime/ranged_guard/attack/06.png",
		"res://assets/sprites/runtime/projectile/flight/04.png"
	]:
		check(FileAccess.file_exists(path), "Required asset should exist: %s" % path)

	game._on_goal_entered(knight)
	check(not game.game_over, "Locked gate should not end the game")
	game.enemies_left = 0
	game._on_goal_entered(knight)
	check(game.game_over and game.won, "Cleared gate should complete the game")

	var feedback := root.get_node_or_null("FeedbackDirector")
	if feedback:
		feedback.reset()
	var audio := root.get_node_or_null("AudioManager")
	paused = true
	if audio:
		audio.release_for_shutdown()
	await create_timer(0.12, true, false, true).timeout
	for transient in get_nodes_in_group("transient_feedback"):
		transient.free()
	game.free()
	var remaining := root.get_children()
	remaining.reverse()
	for child in remaining:
		if is_instance_valid(child):
			child.free()
	paused = false
	await process_frame
	if failures.is_empty():
		print("Little Knight smoke test: PASS")
		quit(0)
	else:
		push_error("Little Knight smoke test: %d failure(s)" % failures.size())
		for failure in failures:
			push_error(" - " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

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
