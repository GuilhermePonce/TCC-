extends RefCounted
class_name GOAPPlanner

func build_plan(world_state: Dictionary, arg2, arg3 = null) -> Array[GOAPAction]:
	var actions: Array[GOAPAction]
	var goal: GOAPGoal
	if arg2 is Array:
		actions = arg2
		goal = arg3
	else:
		goal = arg2
		actions = arg3
	var plan: Array[GOAPAction] = []
	var current_state := world_state.duplicate()
	for goal_key in goal.desired_state.keys():
		if current_state.get(goal_key) == goal.desired_state[goal_key]:
			continue
		var best_action: GOAPAction
		for action in actions:
			if not action.can_run(current_state):
				continue
			if not action.effects.has(goal_key):
				continue
			if action.effects[goal_key] != goal.desired_state[goal_key]:
				continue
			if best_action == null or action.cost < best_action.cost:
				best_action = action
		if best_action:
			plan.append(best_action)
			for effect_key in best_action.effects.keys():
				current_state[effect_key] = best_action.effects[effect_key]
	return plan

func get_plan_cost(plan: Array[GOAPAction]) -> int:
	var total: int = 0
	for action in plan:
		total += action.cost
	return total
