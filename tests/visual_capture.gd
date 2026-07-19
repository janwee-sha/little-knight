extends SceneTree

const COMBAT := preload("res://scripts/combat_rules.gd")
const OUTPUT_DIR := "/private/tmp/little-knight-visual"

var capture_failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	root.get_node("RunState").reset_run()
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	for _frame in 30:
		await physics_frame
	await process_frame
	_capture("gameplay.png")

	game.player.global_position.y -= 24.0
	game.player.velocity.y = 20.0
	game.player.coyote_time = 0.0
	game.player.jump_buffer = 0.13
	game.player._try_jump()
	await create_timer(0.08).timeout
	_capture("double_jump.png")
	game.player.global_position = Vector2(75.0, 310.0 - game.player.ground_offset)
	game.player.velocity = Vector2.ZERO
	game.player.air_jump_used = false
	await process_frame

	game.player.controls_enabled = false
	game.player.velocity = Vector2.ZERO
	game.player.start_heavy_attack()
	await create_timer(0.24).timeout
	_capture("heavy_attack.png")
	game.player._cancel_attack()

	game.player.controls_enabled = true
	game.player.start_guard()
	game.player.perfect_guard_time = 0.0
	await create_timer(0.06).timeout
	_capture("guard.png")
	game.player.stop_guard()
	game.player.perfect_guard_visual_time = 0.4
	await create_timer(0.04).timeout
	_capture("perfect_guard.png")
	game.player.perfect_guard_visual_time = 0.0

	var melee := _find_enemy(game, 0)
	var ranged := _find_enemy(game, 1)
	if melee:
		_prepare_enemy(melee, game.player, Vector2(58, 0))
		melee._start_melee_attack(game.player.global_position - melee.global_position, COMBAT.AttackType.YELLOW, false)
		await create_timer(0.15).timeout
		_capture("enemy_yellow.png")
		melee._cancel_attack()
		melee._start_melee_attack(game.player.global_position - melee.global_position, COMBAT.AttackType.RED, false)
		await create_timer(0.16).timeout
		_capture("enemy_red.png")
		melee._cancel_attack()
	else:
		capture_failed = true
		push_error("Unable to find melee guard for visual capture")

	if ranged:
		_prepare_enemy(ranged, game.player, Vector2(82, 0))
		ranged._start_ranged_cast(game.player.global_position - ranged.global_position, COMBAT.AttackType.RED, false)
		await create_timer(0.18).timeout
		_capture("ranged_red.png")
		ranged._cancel_attack()
	else:
		capture_failed = true
		push_error("Unable to find ranged guard for visual capture")

	game.player.stamina = 8.0
	game.player.stamina_changed.emit(game.player.stamina, game.player.max_stamina)
	await process_frame
	_capture("stamina_low.png")

	var shrine := _find_shrine(game)
	if shrine:
		game.player.global_position = Vector2(1460, 282.5)
		game.player.velocity = Vector2.ZERO
		await create_timer(0.12).timeout
		shrine.set_meta("used", false)
		game._on_shrine_entered(game.player, shrine)
		await create_timer(0.08).timeout
		_capture("checkpoint.png")
	else:
		capture_failed = true
		push_error("Unable to find checkpoint shrine for visual capture")

	game.pause_game()
	await process_frame
	_capture("pause.png")
	paused = false
	game.queue_free()
	await process_frame
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager:
		audio_manager.release_for_shutdown()
	root.get_node("RunState").reset_run()
	await process_frame
	quit(1 if capture_failed else 0)


func _find_enemy(game: Node, kind: int) -> CharacterBody2D:
	for child in game.get_children():
		if child is CharacterBody2D and child != game.player and child.kind == kind:
			return child
	return null


func _find_shrine(game: Node) -> Area2D:
	for child in game.get_children():
		if child is Area2D and child.has_meta("used"):
			return child
	return null


func _prepare_enemy(enemy: CharacterBody2D, player: CharacterBody2D, offset: Vector2) -> void:
	enemy.target = player
	enemy.encounter_active = true
	enemy.velocity = Vector2.ZERO
	enemy.global_position = player.global_position + offset
	enemy.hurt_time = 0.0
	enemy.parried_time = 0.0


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null:
		capture_failed = true
		push_error("Unable to read viewport image for: %s" % file_name)
		return
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		capture_failed = true
		push_error("Unable to write visual capture: %s" % error_string(error))
