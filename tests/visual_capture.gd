extends SceneTree

const OUTPUT_DIR := "/private/tmp/little-knight-visual"
var capture_failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	for _frame in 6:
		await process_frame
	await create_timer(0.12).timeout
	_capture("gameplay.png")
	_capture("grounding.png")
	game.player.start_attack()
	await create_timer(0.13).timeout
	_capture("combat.png")
	_prepare_scale_tableau(game)
	await create_timer(0.08).timeout
	_capture("character_scale.png")
	game.pause_game()
	await process_frame
	_capture("pause.png")
	paused = false
	game.queue_free()
	await process_frame
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager:
		audio_manager.release_for_shutdown()
	await process_frame
	quit(1 if capture_failed else 0)


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


func _prepare_scale_tableau(game: Node) -> void:
	game.player.controls_enabled = false
	game.player.velocity = Vector2.ZERO
	game.player.hurt_time = 0.0
	game.player.invulnerable_time = 0.0
	game.player._cancel_attack()
	game.player.start_attack()
	var offset_x := 90.0
	for child in game.get_children():
		if not (child is CharacterBody2D) or child == game.player:
			continue
		child.target = null
		child.velocity = Vector2.ZERO
		child.global_position = game.player.global_position + Vector2(offset_x, 0)
		child.attack_state = child.AttackState.WINDUP
		child.attack_state_time = 10.0
		child.sprite.play(&"attack")
		offset_x += 80.0
		if offset_x > 180.0:
			break
