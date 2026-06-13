extends "res://scripts/ai/bt/BTControllerBase.gd"
class_name LionBTController

const EXIT_RADIUS_MULTIPLIER := 1.45
const MIN_REACTIVE_NODE_TIME := 0.65

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	update_active_node_time(delta)
	var courage := get_stat_value()
	var enemy := get_nearest_enemy_to_dorothy(_get_detection_radius_for_node())
	var can_leave_reactive_node: bool = active_node_time >= MIN_REACTIVE_NODE_TIME

	if courage <= 30 and enemy:
		succeed("FleeEnemy")
		flee_from_enemy(enemy)
	elif courage >= 70 and enemy:
		succeed("AttackEnemy")
		if attack_enemy(enemy):
			follow_dorothy()
	elif can_leave_reactive_node:
		succeed("FollowDorothy")
		follow_dorothy()
	else:
		companion.velocity = Vector2.ZERO
		companion.move_and_slide()
	_measure_end(start)

func _get_detection_radius_for_node() -> float:
	if active_node == "FleeEnemy" or active_node == "AttackEnemy":
		return companion.enemy_detection_radius * EXIT_RADIUS_MULTIPLIER
	return companion.enemy_detection_radius
