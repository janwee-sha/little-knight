extends SceneTree

const OUTPUT_DIR := "/private/tmp/little-knight-visual"


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
	game.player.start_attack()
	await create_timer(0.13).timeout
	_capture("combat.png")
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
	quit()


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR.path_join(file_name))
	if error != OK:
		push_error("Unable to write visual capture: %s" % error_string(error))
