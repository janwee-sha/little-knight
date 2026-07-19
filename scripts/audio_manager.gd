extends Node

const POOL_SIZE := 14

var _players: Array[AudioStreamPlayer] = []
var _world_players: Array[AudioStreamPlayer2D] = []
var _streams: Dictionary = {}
var _cursor := 0
var _world_cursor := 0
var _ambience_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_build_players()
	_load_streams()
	SettingsStore.sfx_volume_changed.connect(_apply_volume)
	_apply_volume(SettingsStore.sfx_volume)

func play_sfx(event_name: StringName, pitch_variation := 0.04, volume_db := 0.0) -> void:
	var stream: AudioStream = _pick_stream(event_name)
	if stream == null:
		return
	var player := _players[_cursor % _players.size()]
	_cursor += 1
	player.bus = &"UI" if String(event_name).begins_with("ui_") else &"SFX"
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.volume_db = volume_db
	player.play()

func play_world(event_name: StringName, world_position: Vector2, pitch_variation := 0.04, volume_db := 0.0) -> void:
	var stream: AudioStream = _pick_stream(event_name)
	if stream == null:
		return
	var player := _world_players[_world_cursor % _world_players.size()]
	_world_cursor += 1
	player.global_position = world_position
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.volume_db = volume_db
	player.play()

func play_ambience() -> void:
	var stream: AudioStream = _pick_stream(&"ambience_wind")
	if stream == null or _ambience_player.playing:
		return
	_ambience_player.stream = stream
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	_ambience_player.play()

func stop_all() -> void:
	for player in _players:
		player.stop()
	for player in _world_players:
		player.stop()
	_ambience_player.stop()

func release_for_shutdown() -> void:
	stop_all()
	for player in _players:
		player.stream = null
	for player in _world_players:
		player.stream = null
	_ambience_player.stream = null
	_streams.clear()

func _build_players() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	for i in 10:
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX"
		player.max_distance = 460.0
		player.attenuation = 0.65
		add_child(player)
		_world_players.append(player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = &"Ambience"
	_ambience_player.volume_db = -20.0
	add_child(_ambience_player)

func _ensure_audio_buses() -> void:
	for bus_name in [&"SFX", &"UI", &"Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0 and AudioServer.get_bus_effect_count(master_index) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(master_index, limiter)

func _load_streams() -> void:
	var paths := {
		&"ui_focus": ["res://assets/audio/ui_focus.ogg"],
		&"ui_confirm": ["res://assets/audio/ui_confirm.ogg"],
		&"ui_back": ["res://assets/audio/ui_back.ogg"],
		&"jump": ["res://assets/audio/jump.ogg"],
		&"land": ["res://assets/audio/land_1.ogg", "res://assets/audio/land_2.ogg"],
		&"footstep": ["res://assets/audio/footstep_1.ogg", "res://assets/audio/footstep_2.ogg", "res://assets/audio/footstep_3.ogg"],
		&"dash": ["res://assets/audio/dash.ogg"],
		&"swing_1": ["res://assets/audio/swing_1.ogg"],
		&"swing_2": ["res://assets/audio/swing_2.ogg"],
		&"heavy_swing": ["res://assets/audio/swing_2.ogg"],
		&"riposte": ["res://assets/audio/swing_1.ogg", "res://assets/audio/swing_2.ogg"],
		&"hit": ["res://assets/audio/hit_1.ogg", "res://assets/audio/hit_2.ogg", "res://assets/audio/hit_3.ogg"],
		&"hurt": ["res://assets/audio/hurt.ogg"],
		&"guard_block": ["res://assets/audio/hit_1.ogg", "res://assets/audio/hit_2.ogg"],
		&"perfect_guard": ["res://assets/audio/hit_3.ogg", "res://assets/audio/ui_confirm.ogg"],
		&"guard_break": ["res://assets/audio/hurt.ogg", "res://assets/audio/hit_3.ogg"],
		&"stamina_empty": ["res://assets/audio/ui_back.ogg"],
		&"enemy_tell": ["res://assets/audio/enemy_tell.ogg"],
		&"enemy_yellow": ["res://assets/audio/enemy_tell.ogg"],
		&"enemy_red": ["res://assets/audio/cast.ogg"],
		&"cast": ["res://assets/audio/cast.ogg"],
		&"projectile_burst": ["res://assets/audio/projectile_burst.ogg"],
		&"shrine": ["res://assets/audio/shrine.ogg"],
		&"gate": ["res://assets/audio/gate.ogg"],
		&"ambience_wind": ["res://assets/audio/ambience_wind.mp3"]
	}
	for event_name in paths:
		var variants: Array[AudioStream] = []
		for path in paths[event_name]:
			if ResourceLoader.exists(path):
				var stream := load(path) as AudioStream
				if stream:
					variants.append(stream)
		if not variants.is_empty():
			_streams[event_name] = variants

func _pick_stream(event_name: StringName) -> AudioStream:
	if not _streams.has(event_name):
		return null
	var variants: Array = _streams[event_name]
	return variants.pick_random() as AudioStream

func _apply_volume(value: float) -> void:
	var db := linear_to_db(maxf(value, 0.0001))
	for bus_name in [&"SFX", &"UI", &"Ambience"]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, db)
