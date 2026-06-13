extends "res://scripts/ai/bt/BTControllerBase.gd"
class_name ScarecrowBTController

const EXIT_RADIUS_MULTIPLIER := 1.45
const MIN_REACTIVE_NODE_TIME := 0.8

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	update_active_node_time(delta)
	companion.buff_timer = maxf(companion.buff_timer - delta, 0.0)
	var intelligence := get_stat_value()
	var enemy := get_nearest_enemy(_get_detection_radius_for_node())
	var can_leave_reactive_node: bool = active_node_time >= MIN_REACTIVE_NODE_TIME

	if intelligence <= 30 and enemy:
		succeed("ApplyBadStrategy")
	elif intelligence >= 70 and enemy:
		succeed("ApplyBoostStrategy")
	elif can_leave_reactive_node:
		succeed("FollowDorothy")
	_measure_end(start)
	if active_node == "ApplyBadStrategy":
		apply_scarecrow_modifiers("bad_strategy")
	elif active_node == "ApplyBoostStrategy":
		apply_scarecrow_modifiers("buff")
	else:
		apply_scarecrow_modifiers("base")
	follow_dorothy()

func _get_detection_radius_for_node() -> float:
	if active_node == "ApplyBadStrategy" or active_node == "ApplyBoostStrategy":
		return companion.enemy_detection_radius * EXIT_RADIUS_MULTIPLIER
	return companion.enemy_detection_radius
