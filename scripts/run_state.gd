extends Node

enum Checkpoint { START, SHRINE }

var checkpoint: Checkpoint = Checkpoint.START
var tutorial_seen: Dictionary = {}
var health_relic_secured := false

func activate_shrine() -> void:
	checkpoint = Checkpoint.SHRINE

func has_shrine_checkpoint() -> bool:
	return checkpoint == Checkpoint.SHRINE

func secure_health_relic() -> void:
	health_relic_secured = true

func has_secured_health_relic() -> bool:
	return health_relic_secured

func mark_tutorial(key: StringName) -> void:
	tutorial_seen[key] = true

func has_seen_tutorial(key: StringName) -> bool:
	return tutorial_seen.has(key)

func reset_run() -> void:
	checkpoint = Checkpoint.START
	tutorial_seen.clear()
	health_relic_secured = false
