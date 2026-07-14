extends Node2D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")

const WORLD_WIDTH := 5600.0
const GROUND_Y := 620.0

var player: CharacterBody2D
var enemies_total := 0
var enemies_left := 0
var game_over := false
var won := false
var hazard_rects: Array[Rect2] = []
var platform_rects: Array[Rect2] = []
var platform_colors: Array[Color] = []
var health_label: Label
var enemy_label: Label
var dash_label: Label
var toast_label: Label
var center_panel: ColorRect
var center_title: Label
var center_subtitle: Label
var toast_tween: Tween

func _ready() -> void:
	add_to_group("game")
	setup_input_actions()
	build_level()
	build_hud()
	spawn_player()
	spawn_encounters()
	create_goal()
	create_healing_shrine(Vector2(2920, 578))
	queue_redraw()
	show_toast("穿过废墟，击败守卫并抵达右侧城门", 3.2)

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		var ready_text := "READY" if player.dash_cooldown <= 0.0 else "%d%%" % int((1.0 - player.dash_cooldown / 0.72) * 100.0)
		dash_label.text = "DASH  " + ready_text
	if game_over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func setup_input_actions() -> void:
	add_key_action("move_left", [KEY_A, KEY_LEFT])
	add_key_action("move_right", [KEY_D, KEY_RIGHT])
	add_key_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	add_key_action("attack", [KEY_J, KEY_Z])
	add_key_action("dash", [KEY_K, KEY_X, KEY_SHIFT])
	add_key_action("restart", [KEY_R])
	add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	add_joy_button("jump", JOY_BUTTON_A)
	add_joy_button("attack", JOY_BUTTON_X)
	add_joy_button("dash", JOY_BUTTON_B)

func add_key_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

func add_joy_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func build_level() -> void:
	# Five ground islands make the player mix jumping and dashing with combat.
	add_platform(Rect2(-80, GROUND_Y, 1110, 180), Color("273a4d"))
	add_platform(Rect2(1200, GROUND_Y, 850, 180), Color("2b4050"))
	add_platform(Rect2(2240, GROUND_Y, 850, 180), Color("283d4a"))
	add_platform(Rect2(3270, GROUND_Y, 820, 180), Color("2b4050"))
	add_platform(Rect2(4250, GROUND_Y, 1450, 180), Color("273a4d"))
	# One-way bridge stones and elevated ruins.
	add_platform(Rect2(1055, 550, 105, 24), Color("536c72"), true)
	add_platform(Rect2(2078, 545, 92, 24), Color("536c72"), true)
	add_platform(Rect2(2175, 500, 72, 22), Color("5e7478"), true)
	add_platform(Rect2(3105, 548, 104, 24), Color("536c72"), true)
	add_platform(Rect2(4140, 535, 78, 22), Color("5e7478"), true)
	add_platform(Rect2(640, 470, 180, 25), Color("526b72"), true)
	add_platform(Rect2(1490, 455, 210, 25), Color("526b72"), true)
	add_platform(Rect2(2500, 475, 190, 25), Color("526b72"), true)
	add_platform(Rect2(3450, 450, 200, 25), Color("526b72"), true)
	add_platform(Rect2(4650, 470, 190, 25), Color("526b72"), true)
	# Invisible left boundary.
	add_platform(Rect2(-40, 0, 40, 720), Color.TRANSPARENT)
	add_spikes(Rect2(720, 594, 126, 26))
	add_spikes(Rect2(1740, 594, 112, 26))
	add_spikes(Rect2(2770, 594, 136, 26))
	add_spikes(Rect2(3730, 594, 120, 26))
	add_spikes(Rect2(4900, 594, 150, 26))

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
	shape_node.one_way_collision_margin = 12.0
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
	box.size = Vector2(rect.size.x - 8.0, rect.size.y * 0.72)
	shape_node.position.y = rect.size.y * 0.2
	shape_node.shape = box
	area.add_child(shape_node)
	area.body_entered.connect(_on_hazard_entered)
	add_child(area)

func _on_hazard_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		var direction := signf(body.global_position.x - 2800.0)
		if direction == 0.0:
			direction = 1.0
		body.take_damage(1, Vector2(direction * 170.0, -390.0))

func spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.position = Vector2(150, 565)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	add_child(player)

func spawn_encounters() -> void:
	spawn_enemy(Vector2(905, 570), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(1535, 570), ENEMY_SCRIPT.Kind.RANGED)
	spawn_enemy(Vector2(1910, 570), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(2530, 570), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(3500, 570), ENEMY_SCRIPT.Kind.RANGED)
	spawn_enemy(Vector2(3980, 570), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(4620, 570), ENEMY_SCRIPT.Kind.MELEE)
	spawn_enemy(Vector2(5200, 570), ENEMY_SCRIPT.Kind.RANGED)

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
	update_enemy_label()
	if enemies_left == 0 and not game_over:
		show_toast("所有守卫已被击败，城门开启！", 2.8)

func create_goal() -> void:
	var goal := Area2D.new()
	goal.position = Vector2(5480, 540)
	goal.collision_layer = 0
	goal.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(105, 160)
	shape_node.shape = box
	goal.add_child(shape_node)
	goal.body_entered.connect(_on_goal_entered)
	add_child(goal)

func _on_goal_entered(body: Node) -> void:
	if body != player or game_over:
		return
	if enemies_left > 0:
		show_toast("城门被封印了——还剩 %d 名守卫" % enemies_left, 2.0)
		return
	win_game()

func create_healing_shrine(where: Vector2) -> void:
	var shrine := Area2D.new()
	shrine.position = where
	shrine.collision_layer = 0
	shrine.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape_node.shape = circle
	shrine.add_child(shape_node)
	shrine.body_entered.connect(_on_shrine_entered.bind(shrine))
	shrine.set_meta("used", false)
	add_child(shrine)

func _on_shrine_entered(body: Node, shrine: Area2D) -> void:
	if body != player or shrine.get_meta("used"):
		return
	if player.health >= player.max_health:
		show_toast("月光祭坛：生命值已满", 1.4)
		return
	shrine.set_meta("used", true)
	player.heal(2)
	show_toast("月光祭坛恢复了 2 点生命", 1.8)
	var tween := shrine.create_tween()
	tween.tween_property(shrine, "modulate:a", 0.0, 0.35)

func build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.035, 0.047, 0.09, 0.86)
	top_bar.position = Vector2(24, 22)
	top_bar.size = Vector2(400, 72)
	hud.add_child(top_bar)
	health_label = make_label(Vector2(22, 8), Vector2(220, 28), 24, Color("ffdf8c"))
	top_bar.add_child(health_label)
	enemy_label = make_label(Vector2(22, 39), Vector2(220, 24), 17, Color("c7d9e8"))
	top_bar.add_child(enemy_label)
	dash_label = make_label(Vector2(260, 22), Vector2(125, 28), 15, Color("90f1ef"))
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(dash_label)

	var title := make_label(Vector2(-330, 24), Vector2(300, 38), 26, Color("f7e8c6"))
	title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.text = "LITTLE KNIGHT"
	hud.add_child(title)
	var controls := make_label(Vector2(-500, 58), Vector2(470, 32), 14, Color(0.78, 0.84, 0.9, 0.86))
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.text = "A/D 移动   SPACE 跳跃   J 攻击   K/SHIFT 闪避"
	hud.add_child(controls)

	toast_label = make_label(Vector2(-330, 112), Vector2(660, 44), 18, Color("f7e8c6"))
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	hud.add_child(toast_label)

	center_panel = ColorRect.new()
	center_panel.color = Color(0.025, 0.032, 0.065, 0.94)
	center_panel.position = Vector2(-270, -120)
	center_panel.size = Vector2(540, 240)
	center_panel.set_anchors_preset(Control.PRESET_CENTER)
	center_panel.visible = false
	hud.add_child(center_panel)
	center_title = make_label(Vector2(20, 40), Vector2(500, 70), 42, Color("ffdf8c"))
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_panel.add_child(center_title)
	center_subtitle = make_label(Vector2(30, 120), Vector2(480, 74), 18, Color("c7d9e8"))
	center_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_panel.add_child(center_subtitle)
	update_enemy_label()

func make_label(where: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = where
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _on_player_health_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(health_label):
		return
	var hearts := ""
	for i in maximum:
		hearts += "◆ " if i < current else "◇ "
	health_label.text = hearts.strip_edges()

func update_enemy_label() -> void:
	if is_instance_valid(enemy_label):
		enemy_label.text = "守卫  %d / %d" % [enemies_left, enemies_total]

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	center_panel.visible = true
	center_title.text = "FALLEN"
	center_title.add_theme_color_override("font_color", Color("ff7b72"))
	center_subtitle.text = "小骑士倒下了\n按 R 重新开始"

func win_game() -> void:
	game_over = true
	won = true
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	center_panel.visible = true
	center_title.text = "DAWN AWAITS"
	center_title.add_theme_color_override("font_color", Color("ffdf8c"))
	center_subtitle.text = "你穿过了暮色废墟！\n按 R 再玩一次"

func show_toast(message: String, duration := 2.0) -> void:
	if not is_instance_valid(toast_label):
		return
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_label.text = message
	toast_label.modulate.a = 0.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 1.0, 0.18)
	toast_tween.tween_interval(duration)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.35)

func _draw() -> void:
	# World-space backdrop, layered to give the camera a parallax-like sense of depth.
	draw_rect(Rect2(0, 0, WORLD_WIDTH, 720), Color("111a33"))
	draw_rect(Rect2(0, 300, WORLD_WIDTH, 420), Color("1a2942"))
	for i in 90:
		var x := fmod(float(i * 347 + 91), WORLD_WIDTH)
		var y := float(35 + (i * 83) % 250)
		var radius := 1.0 + float(i % 3) * 0.55
		draw_circle(Vector2(x, y), radius, Color(0.78, 0.88, 1.0, 0.35 + (i % 4) * 0.1))
	# Moon.
	draw_circle(Vector2(470, 165), 76, Color(0.65, 0.78, 0.9, 0.12))
	draw_circle(Vector2(470, 165), 49, Color("dce9f2"))
	draw_circle(Vector2(488, 150), 47, Color("111a33"))
	# Distant mountain and castle silhouettes repeated through the level.
	for section in 7:
		var base_x := float(section) * 850.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x - 180, 470), Vector2(base_x + 120, 235),
			Vector2(base_x + 315, 470), Vector2(base_x + 535, 290),
			Vector2(base_x + 850, 470)
		]), Color("23344e"))
		draw_rect(Rect2(base_x + 520, 325, 115, 180), Color("1c2940"))
		draw_rect(Rect2(base_x + 535, 285, 25, 70), Color("1c2940"))
		draw_rect(Rect2(base_x + 595, 280, 25, 75), Color("1c2940"))
	# Mist bands.
	for i in 12:
		var mist_x := float(i) * 520.0 - 120.0
		draw_oval(Vector2(mist_x, 500 + (i % 2) * 35), Vector2(220, 36), Color(0.45, 0.58, 0.68, 0.055))
	# Platforms get stone caps and subtle brick seams.
	for i in platform_rects.size():
		var rect := platform_rects[i]
		var color := platform_colors[i]
		draw_rect(rect, color)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(10.0, rect.size.y))), color.lightened(0.25))
		if rect.size.y > 30.0:
			var bricks := int(rect.size.x / 80.0)
			for brick in bricks:
				var bx := rect.position.x + brick * 80.0 + (40.0 if brick % 2 else 0.0)
				draw_line(Vector2(bx, rect.position.y + 36), Vector2(bx + 45, rect.position.y + 36), Color(0.08, 0.12, 0.17, 0.32), 2.0)
	# Spikes.
	for rect in hazard_rects:
		var count := maxi(1, int(rect.size.x / 18.0))
		var width := rect.size.x / count
		for spike in count:
			var left := rect.position.x + spike * width
			draw_colored_polygon(PackedVector2Array([
				Vector2(left, rect.end.y), Vector2(left + width * 0.5, rect.position.y), Vector2(left + width, rect.end.y)
			]), Color("b8c7d1"))
	# Healing shrine and final gate.
	draw_circle(Vector2(2920, 578), 25, Color(0.45, 0.95, 0.88, 0.12))
	draw_circle(Vector2(2920, 578), 12, Color("90f1ef"))
	draw_polygon(PackedVector2Array([Vector2(2900,620), Vector2(2910,588), Vector2(2930,588), Vector2(2940,620)]), PackedColorArray([Color("506c78")]))
	draw_rect(Rect2(5400, 420, 150, 200), Color("151b2d"))
	draw_arc(Vector2(5475, 500), 75, PI, TAU, 28, Color("617889"), 14)
	draw_rect(Rect2(5400, 500, 14, 120), Color("617889"))
	draw_rect(Rect2(5536, 500, 14, 120), Color("617889"))
	draw_line(Vector2(5475, 430), Vector2(5475, 390), Color("d1495b"), 5)
	draw_colored_polygon(PackedVector2Array([Vector2(5475,390), Vector2(5540,410), Vector2(5475,430)]), Color("d1495b"))

func draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
