extends "res://scripts/ai/goap/GOAPControllerBase.gd"
class_name TinManGOAPController

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	var empathy := get_stat_value()
	var dorothy := get_dorothy()
	var lion := get_companion_by_id("lion")
	var goal := GOAPGoalScript.new("FollowDorothy", {"near_dorothy": true}, 1)
	if empathy <= 30 and is_combat_active():
		goal = GOAPGoalScript.new("AvoidCombat", {"combat_ignored": true}, 2)
	elif empathy >= 70 and is_injured(dorothy, 0.70):
		goal = GOAPGoalScript.new("KeepDorothyAlive", {"dorothy_healed": true}, 3)
	elif empathy >= 70 and is_injured(lion, 0.70):
		goal = GOAPGoalScript.new("KeepLionAlive", {"lion_healed": true}, 3)
	elif empathy > 30 and empathy < 70 and is_injured(dorothy, 0.35):
		goal = GOAPGoalScript.new("KeepDorothyAlive", {"dorothy_healed": true}, 2)
	var actions: Array[GOAPAction] = [
		GOAPActionScript.new("MoveToDorothy", 1, {}, {"near_dorothy": true}),
		GOAPActionScript.new("HealDorothy", 1, {"near_dorothy": true}, {"dorothy_healed": true}),
		GOAPActionScript.new("MoveToLion", 1, {}, {"near_lion": true}),
		GOAPActionScript.new("HealLion", 1, {"near_lion": true}, {"lion_healed": true}),
		GOAPActionScript.new("IgnoreCombat", 1, {}, {"combat_ignored": true}),
	]
	var plan := planner.build_plan({}, goal, actions)
	set_plan(goal, plan)
	if current_goal == "KeepDorothyAlive":
		if not is_valid_living_ally(dorothy):
			invalidate_plan("heal_target_dead")
			follow_dorothy()
		elif heal_ally(dorothy):
			follow_dorothy()
	elif current_goal == "KeepLionAlive":
		if not is_valid_living_ally(lion):
			invalidate_plan("heal_target_dead")
			follow_dorothy()
		elif heal_ally(lion):
			follow_dorothy()
	elif current_goal == "AvoidCombat":
		follow_dorothy()
	else:
		follow_dorothy()
	_measure_end(start)
