extends "res://scripts/ai/goap/GOAPControllerBase.gd"
class_name ScarecrowGOAPController

const EXIT_RADIUS_MULTIPLIER := 1.45
const MIN_REACTIVE_GOAL_TIME := 0.8

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	update_goal_time(delta)
	companion.buff_timer = maxf(companion.buff_timer - delta, 0.0)
	var intelligence := get_stat_value()
	var enemy := get_nearest_enemy(_get_detection_radius_for_goal())
	var goal := GOAPGoalScript.new("FollowDorothy", {"near_dorothy": true}, 1)
	var can_leave_reactive_goal: bool = goal_time >= MIN_REACTIVE_GOAL_TIME
	if current_goal != "FollowDorothy" and not can_leave_reactive_goal:
		goal = GOAPGoalScript.new(current_goal, _goal_state_for_name(current_goal), 3)
	elif intelligence <= 30 and enemy:
		goal = GOAPGoalScript.new("BadStrategy", {"allies_weakened": true, "enemies_buffed": true, "bad_strategy_done": true}, 3)
	elif intelligence >= 70 and enemy:
		goal = GOAPGoalScript.new("ImproveAllies", {"dorothy_buffed": true, "allies_buffed": true, "enemies_weakened": true}, 3)
	var actions: Array[GOAPAction] = [
		GOAPActionScript.new("BuffAllies", 1, {}, {"dorothy_buffed": true, "allies_buffed": true}),
		GOAPActionScript.new("DebuffEnemies", 1, {"allies_buffed": true}, {"enemies_weakened": true}),
		GOAPActionScript.new("WeakenAllies", 1, {}, {"allies_weakened": true}),
		GOAPActionScript.new("BuffEnemies", 1, {"allies_weakened": true}, {"enemies_buffed": true, "bad_strategy_done": true}),
		GOAPActionScript.new("MoveToDorothy", 1, {}, {"near_dorothy": true}),
	]
	var plan := planner.build_plan({}, goal, actions)
	set_plan(goal, plan)
	_measure_end(start)
	if current_goal == "ImproveAllies":
		if not is_valid_living_target(enemy):
			invalidate_plan("target_dead")
		else:
			apply_scarecrow_modifiers("buff")
	elif current_goal == "BadStrategy":
		if not is_valid_living_target(enemy):
			invalidate_plan("target_dead")
		else:
			apply_scarecrow_modifiers("bad_strategy")
	else:
		apply_scarecrow_modifiers("base")
	follow_dorothy()

func _get_detection_radius_for_goal() -> float:
	if current_goal == "ImproveAllies" or current_goal == "BadStrategy":
		return companion.enemy_detection_radius * EXIT_RADIUS_MULTIPLIER
	return companion.enemy_detection_radius

func _goal_state_for_name(goal_name: String) -> Dictionary:
	match goal_name:
		"ImproveAllies":
			return {"dorothy_buffed": true, "allies_buffed": true, "enemies_weakened": true}
		"BadStrategy":
			return {"allies_weakened": true, "enemies_buffed": true, "bad_strategy_done": true}
	return {"near_dorothy": true}
