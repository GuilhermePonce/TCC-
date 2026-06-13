extends "res://scripts/ai/goap/GOAPControllerBase.gd"
class_name LionGOAPController

const EXIT_RADIUS_MULTIPLIER := 1.45
const MIN_REACTIVE_GOAL_TIME := 0.65

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	update_goal_time(delta)
	var enemy := get_nearest_enemy_to_dorothy(_get_detection_radius_for_goal())
	var courage := get_stat_value()
	var goal := GOAPGoalScript.new("FollowDorothy", {"near_dorothy": true}, 1)
	var can_leave_reactive_goal: bool = goal_time >= MIN_REACTIVE_GOAL_TIME
	if current_goal != "FollowDorothy" and not can_leave_reactive_goal:
		goal = GOAPGoalScript.new(current_goal, _goal_state_for_name(current_goal), 3)
	elif courage >= 70 and enemy:
		goal = GOAPGoalScript.new("ProtectDorothy", {"enemy_attacked": true}, 3)
	elif courage <= 30 and enemy:
		goal = GOAPGoalScript.new("StaySafe", {"safe": true}, 3)
	var actions: Array[GOAPAction] = [
		GOAPActionScript.new("MoveToEnemy", 1, {}, {"near_enemy": true}),
		GOAPActionScript.new("AttackEnemy", 1, {"near_enemy": true}, {"enemy_attacked": true}),
		GOAPActionScript.new("FleeFromEnemy", 1, {}, {"safe": true}),
		GOAPActionScript.new("MoveToDorothy", 1, {}, {"near_dorothy": true}),
	]
	var plan := planner.build_plan({}, goal, actions)
	set_plan(goal, plan)
	if current_goal == "ProtectDorothy":
		if not is_valid_living_target(enemy):
			invalidate_plan("target_dead")
			follow_dorothy()
		elif attack_enemy(enemy):
			follow_dorothy()
	elif current_goal == "StaySafe":
		if is_valid_living_target(enemy):
			flee_from_enemy(enemy)
		else:
			invalidate_plan("target_dead")
			follow_dorothy()
	else:
		follow_dorothy()
	_measure_end(start)

func _get_detection_radius_for_goal() -> float:
	if current_goal == "ProtectDorothy" or current_goal == "StaySafe":
		return companion.enemy_detection_radius * EXIT_RADIUS_MULTIPLIER
	return companion.enemy_detection_radius

func _goal_state_for_name(goal_name: String) -> Dictionary:
	match goal_name:
		"ProtectDorothy":
			return {"enemy_attacked": true}
		"StaySafe":
			return {"safe": true}
	return {"near_dorothy": true}
