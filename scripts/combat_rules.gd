extends RefCounted

enum AttackType { NORMAL, YELLOW, RED, ENVIRONMENT }
enum HitResult { HIT, BLOCKED, PERFECT_GUARD, GUARD_BROKEN, EVADED }
enum PlayerMove { LIGHT_ONE, LIGHT_TWO, HEAVY, RIPOSTE }

static func health_damage_for(attack_type: int) -> int:
	match attack_type:
		AttackType.YELLOW, AttackType.RED:
			return 2
		_:
			return 1

class HitData:
	extends RefCounted

	var attack_type: int
	var health_damage: int
	var guard_cost: float
	var perfect_guard_cost: float
	var knockback: Vector2
	var source: Node2D

	func _init(
		type_value: int,
		damage_value: int,
		guard_cost_value: float,
		perfect_guard_cost_value: float,
		knockback_value: Vector2,
		source_value: Node2D
	) -> void:
		attack_type = type_value
		health_damage = damage_value
		guard_cost = guard_cost_value
		perfect_guard_cost = perfect_guard_cost_value
		knockback = knockback_value
		source = source_value
