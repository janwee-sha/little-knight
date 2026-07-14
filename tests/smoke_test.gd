extends SceneTree

var game: Node2D

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(game)
	run_checks.call_deferred()

func run_checks() -> void:
	await process_frame
	await process_frame
	assert(is_instance_valid(game.player), "Player should be created")
	assert(game.enemies_total == 8, "All encounters should be created")
	assert(game.enemies_left == 8, "Enemy counter should start full")

	var knight: CharacterBody2D = game.player
	var initial_health: int = knight.health
	knight.start_dash()
	knight.take_damage(1, Vector2.ZERO)
	assert(knight.health == initial_health, "Dash should grant invulnerability")
	knight.dash_time = 0.0
	knight.invulnerable_time = 0.0
	knight.take_damage(1, Vector2.ZERO)
	assert(knight.health == initial_health - 1, "Damage should reduce health")
	knight.heal(1)
	assert(knight.health == initial_health, "Healing should restore health")

	Input.action_press("attack")
	knight._physics_process(0.016)
	Input.action_release("attack")
	assert(knight.attack_cooldown > 0.0, "Attack input should start an attack")

	game._on_goal_entered(knight)
	assert(not game.game_over, "Locked gate should not end the game")
	game.enemies_left = 0
	game._on_goal_entered(knight)
	assert(game.game_over and game.won, "Cleared gate should complete the game")
	print("Little Knight smoke test: PASS")
	quit()
