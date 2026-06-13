extends "res://scripts/ai/AIControllerBase.gd"
class_name GOAPControllerBase

const GOAPPlannerScript := preload("res://scripts/ai/goap/GOAPPlanner.gd")
const GOAPActionScript := preload("res://scripts/ai/goap/GOAPAction.gd")
const GOAPGoalScript := preload("res://scripts/ai/goap/GOAPGoal.gd")

var current_goal: String = "FollowDorothy"
var current_plan: Array[String] = []
var current_action: String = ""
var last_plan_failure_reason: String = ""
var plan_cost: int = 0
var planner: GOAPPlanner = GOAPPlannerScript.new()
var goal_time: float = 0.0

func get_algorithm_name() -> String:
	return "GOAP"

func get_debug_state() -> String:
	if debug_state == "Dead" or debug_state == "Dorothy is down" or debug_state == "No active player target" or debug_state.begins_with("Fallback:"):
		return debug_state
	if not last_plan_failure_reason.is_empty():
		return "GOAP Plan invalidated, replanning"
	return "GOAP Goal: %s | Current Plan: %s | Action: %s | Plan Cost: %s" % [current_goal, " -> ".join(current_plan), current_action, plan_cost]

func get_metrics_data() -> Dictionary:
	var data := super.get_metrics_data()
	data["goap_goal"] = current_goal
	data["goap_plan"] = current_plan.duplicate()
	data["goap_action"] = current_action
	data["plan_cost"] = plan_cost
	data["last_plan_failure_reason"] = last_plan_failure_reason
	return data

func set_plan(goal: GOAPGoal, plan: Array[GOAPAction]) -> void:
	if current_goal != goal.name:
		goal_time = 0.0
		last_plan_failure_reason = ""
	current_goal = goal.name
	current_plan.clear()
	for action in plan:
		current_plan.append(action.name)
	current_action = current_plan[0] if not current_plan.is_empty() else ""
	plan_cost = planner.get_plan_cost(plan)
	if current_plan.is_empty() and current_goal != "FollowDorothy":
		invalidate_plan("no_valid_plan")
	elif not current_plan.is_empty():
		last_plan_failure_reason = ""

func update_goal_time(delta: float) -> void:
	goal_time += delta

func invalidate_plan(reason: String) -> void:
	last_plan_failure_reason = reason
	current_action = ""
	current_plan.clear()
	plan_cost = 0
	_log_edge_event("plan_invalidated", {"npc": _npc_id(), "reason": reason})

func on_scenario_changed() -> void:
	super.on_scenario_changed()
	current_goal = "FollowDorothy"
	current_plan.clear()
	current_action = ""
	last_plan_failure_reason = ""
	plan_cost = 0
	goal_time = 0.0
