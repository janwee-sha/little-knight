extends Node2D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const HUD_SCRIPT := preload("res://scripts/hud.gd")
const PAUSE_MENU_SCRIPT := preload("res://scripts/pause_menu.gd")
const BACKGROUND_TEXTURE := preload("res://assets/backgrounds/moonlit_ruins.png")

const WORLD_WIDTH := 2800.0
const GROUND_Y := 310.0

var player: CharacterBody2D
var hud: CanvasLayer
var pause_menu: CanvasLayer
var enemies_total := 0
var enemies_left := 0
var game_over := false
var won := false
var hazard_rects: Array[Rect2] = []
var platform_rects: Array[Rect2] = []
var platform_colors: Array[Color] = []

func _ready() -> void:
	get_tree().paused = false
	FeedbackDirector.reset()
	add_to_group("game")
	build_backdrop()
	build_level()
	build_interfaces()
	spawn_player()
	spawn_encounters()
	create_goal()
	create_healing_shrine(Vector2(1460, 289))
	hud.set_enemy_count(enemies_left, enemies_total)
	queue_redraw()
	hud.show_toast("穿过废墟，击败守卫并抵达右侧城门", 3.2)
	AudioManager.play_ambience()

func _exit_tree() -> void:
	FeedbackDirector.reset()

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		hud.set_dash_cooldown(player.dash_cooldown, 0.72)
	if game_over and Input.is_action_just_pressed("restart"):
		restart_game()


func build_backdrop() -> void:
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.name = "BackdropLayer"
	backdrop_layer.layer = -100
	var backdrop := TextureRect.new()
	backdrop.name = "MoonlitRuins"
	backdrop.texture = BACKGROUND_TEXTURE
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(640, 360)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop_layer.add_child(backdrop)
	add_child(backdrop_layer)

func build_interfaces() -> void:
	hud = HUD_SCRIPT.new()
	hud.restart_requested.connect(restart_game)
	hud.quit_requested.connect(quit_game)
	add_child(hud)
	pause_menu = PAUSE_MENU_SCRIPT.new()
	pause_menu.pause_requested.connect(pause_game)
	pause_menu.resume_requested.connect(resume_game)
	pause_menu.restart_requested.connect(restart_game)
	pause_menu.quit_requested.connect(quit_game)
	add_child(pause_menu)

func pause_game() -> void:
	if game_over or get_tree().paused:
		return
	pause_menu.open()
	get_tree().paused = true

func resume_game() -> void:
	if not get_tree().paused:
		return
	get_tree().paused = false
	pause_menu.close()

func restart_game() -> void:
	get_tree().paused = false
	FeedbackDirector.reset()
	AudioManager.stop_all()
	get_tree().reload_current_scene()

func quit_game() -> void:
	get_tree().paused = false
	FeedbackDirector.reset()
	get_tree().quit()

func build_level() -> void:
	add_platform(Rect2(-40, GROUND_Y, 555, 90), Color("26394b"))
	add_platform(Rect2(600, GROUND_Y, 425, 90), Color("2a4050"))
	add_platform(Rect2(1120, GROUND_Y, 425, 90), Color("273d49"))
	add_platform(Rect2(1635, GROUND_Y, 410, 90), Color("2a4050"))
	add_platform(Rect2(2125, GROUND_Y, 725, 90), Color("26394b"))
	add_platform(Rect2(527.5, 275, 52.5, 12), Color("526b72"), true)
	add_platform(Rect2(1039, 272.5, 46, 12), Color("526b72"), true)
	add_platform(Rect2(1087.5, 250, 36, 11), Color("5d7478"), true)
	add_platform(Rect2(1552.5, 274, 52, 12), Color("526b72"), true)
	add_platform(Rect2(2070, 267.5, 39, 11), Color("5d7478"), true)
	add_platform(Rect2(320, 235, 90, 13), Color("526b72"), true)
	add_platform(Rect2(745, 227.5, 105, 13), Color("526b72"), true)
	add_platform(Rect2(1250, 237.5, 95, 13), Color("526b72"), true)
	add_platform(Rect2(1725, 225, 100, 13), Color("526b72"), true)
	add_platform(Rect2(2325, 235, 95, 13), Color("526b72"), true)
	add_platform(Rect2(-20, 0, 20, 360), Color.TRANSPARENT)
	add_spikes(Rect2(360, 297, 63, 13))
	add_spikes(Rect2(870, 297, 56, 13))
	add_spikes(Rect2(1385, 297, 68, 13))
	add_spikes(Rect2(1865, 297, 60, 13))
	add_spikes(Rect2(2450, 297, 75, 13))

func add_platform(rect: Rect2, color: Color, one_way := false) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape_node.shape = box
	shape_node.one_way_collision = one_way
	shape_node.one_way_collision_margin = 6.0
	body.add_child(shape_node)
	add_child(body)
	if color.a > 0.0:
		platform_rects.append(rect)
		platform_colors.append(color)

func add_spikes(rect: Rect2) -> void:
	hazard_rects.append(rect)
	var area := Area2D.new()
	area.position = rect.position + rect.size * 0.5
	area.collision_layer = 8
	area.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(rect.size.x - 4.0, rect.size.y * 0.72)
	shape_node.position.y = rect.size.y * 0.2
	shape_node.shape = box
	area.add_child(shape_node)
	area.body_entered.connect(_on_hazard_entered)
	add_child(area)

func _on_hazard_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		var direction := signf(body.global_position.x - 1400.0)
		if direction == 0.0:
			direction = 1.0
		body.take_damage(1, Vector2(direction * 85.0, -195.0))

func spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.position = Vector2(75, 282.5)
	player.health_changed.connect(_on_player_health_changed)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	add_child(player)

func spawn_encounters() -> void:
	spawn_enemy(Vector2(452.5, 285), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(767.5, 285), ENEMY_SCRIPT.Kind.RANGED)
	spawn_enemy(Vector2(955, 285), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(1265, 285), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(1750, 285), ENEMY_SCRIPT.Kind.RANGED)
	spawn_enemy(Vector2(1990, 285), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(2310, 285), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(2600, 285), ENEMY_SCRIPT.Kind.RANGED)

func spawn_enemy(where: Vector2, enemy_kind: int) -> void:
	var enemy := ENEMY_SCRIPT.new()
	enemy.kind = enemy_kind
	enemy.target = player
	enemy.position = where
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)
	enemies_total += 1
	enemies_left += 1

func spawn_projectile(start: Vector2, direction: Vector2) -> void:
	if game_over:
		return
	var projectile := PROJECTILE_SCRIPT.new()
	projectile.setup(start, direction)
	add_child(projectile)

func _on_enemy_defeated(_enemy: Node) -> void:
	enemies_left = maxi(enemies_left - 1, 0)
	hud.set_enemy_count(enemies_left, enemies_total)
	if enemies_left == 0 and not game_over:
		hud.show_toast("所有守卫已被击败，城门开启！", 2.8)
		AudioManager.play_world(&"gate", Vector2(2738, 250), 0.02, -1.0)

func create_goal() -> void:
	var goal := Area2D.new()
	goal.position = Vector2(2740, 270)
	goal.collision_layer = 0
	goal.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(53, 80)
	shape_node.shape = box
	goal.add_child(shape_node)
	goal.body_entered.connect(_on_goal_entered)
	add_child(goal)

func _on_goal_entered(body: Node) -> void:
	if body != player or game_over:
		return
	if enemies_left > 0:
		hud.show_toast("城门被封印了——还剩 %d 名守卫" % enemies_left, 2.0)
		return
	win_game()

func create_healing_shrine(where: Vector2) -> void:
	var shrine := Area2D.new()
	shrine.position = where
	shrine.collision_layer = 0
	shrine.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape_node.shape = circle
	shrine.add_child(shape_node)
	shrine.body_entered.connect(_on_shrine_entered.bind(shrine))
	shrine.set_meta("used", false)
	add_child(shrine)

func _on_shrine_entered(body: Node, shrine: Area2D) -> void:
	if body != player or shrine.get_meta("used"):
		return
	if player.health >= player.max_health:
		hud.show_toast("月光祭坛：生命值已满", 1.4)
		return
	shrine.set_meta("used", true)
	player.heal(2)
	AudioManager.play_world(&"shrine", shrine.global_position, 0.02, -1.0)
	FeedbackDirector.request_hit(shrine.global_position, false, false, Color("90f1ef"))
	hud.show_toast("月光祭坛恢复了 2 点生命", 1.8)
	var tween := shrine.create_tween()
	tween.tween_property(shrine, "modulate:a", 0.0, 0.35)

func _on_player_health_changed(current: int, maximum: int) -> void:
	hud.set_health(current, maximum)

func _on_player_damaged(_amount: int) -> void:
	hud.flash_hurt()

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	hud.show_terminal(false)

func win_game() -> void:
	game_over = true
	won = true
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	AudioManager.play_world(&"gate", Vector2(2740, 270), 0.0, 0.0)
	hud.show_terminal(true)

func _draw() -> void:
	# Imported backdrop carries the environment art; this translucent sill keeps
	# the collision-ground silhouette readable over its foreground detail.
	draw_rect(Rect2(0, 282, WORLD_WIDTH, 78), Color(0.025, 0.045, 0.08, 0.32))
	for i in platform_rects.size():
		var rect := platform_rects[i]
		var color := platform_colors[i]
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(5.0, rect.size.y))), color.lightened(0.24))
		if rect.size.y > 15.0:
			var rows := int(rect.size.y / 12.0)
			var columns := int(rect.size.x / 24.0)
			for row in rows:
				for column in columns:
					var seam_x := rect.position.x + column * 24.0 + (12.0 if row % 2 else 0.0)
					var seam_y := rect.position.y + 12.0 + row * 12.0
					draw_line(Vector2(seam_x, seam_y), Vector2(minf(seam_x + 16.0, rect.end.x), seam_y), Color(0.05, 0.08, 0.12, 0.38), 1.0)
	for rect in hazard_rects:
		var count := maxi(1, int(rect.size.x / 9.0))
		var width := rect.size.x / count
		for spike in count:
			var left := rect.position.x + spike * width
			draw_colored_polygon(PackedVector2Array([
				Vector2(left, rect.end.y), Vector2(left + width * 0.5, rect.position.y), Vector2(left + width, rect.end.y)
			]), Color("aebfc9"))
	# Shrine and final gate staging art.
	draw_rect(Rect2(1454, 281, 12, 8), Color(0.45, 0.95, 0.88, 0.25))
	draw_rect(Rect2(1457, 284, 6, 6), Color("90f1ef"))
	draw_colored_polygon(PackedVector2Array([Vector2(1450, 310), Vector2(1455, 294), Vector2(1465, 294), Vector2(1470, 310)]), Color("506c78"))
	draw_rect(Rect2(2700, 210, 75, 100), Color("111829"))
	draw_rect(Rect2(2700, 250, 7, 60), Color("5a7183"))
	draw_rect(Rect2(2768, 250, 7, 60), Color("5a7183"))
	for i in 7:
		draw_rect(Rect2(2707 + i * 9, 226 - abs(3 - i) * 3, 9, 7), Color("5a7183"))
	draw_line(Vector2(2738, 215), Vector2(2738, 195), Color("c84455"), 3)
	draw_colored_polygon(PackedVector2Array([Vector2(2738,195), Vector2(2770,205), Vector2(2738,215)]), Color("c84455"))
