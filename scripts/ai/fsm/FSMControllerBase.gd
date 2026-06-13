extends "res://scripts/ai/AIControllerBase.gd"
class_name FSMControllerBase

var state: String = "FOLLOW_DOROTHY"
var last_transition: String = "None"
var state_time: float = 0.0

func get_algorithm_name() -> String:
	return "FSM"

func update_state_time(delta: float) -> void:
	state_time += delta

func transition_to(new_state: String) -> void:
	if state == new_state:
		return
	last_transition = "%s -> %s" % [state, new_state]
	state = new_state
	state_time = 0.0

func get_debug_state() -> String:
	if debug_state == "Dead" or debug_state == "Dorothy is down" or debug_state == "No active player target" or debug_state.begins_with("Fallback:"):
		return debug_state
	return "FSM State: %s | Last Transition: %s" % [state, last_transition]

func get_metrics_data() -> Dictionary:
	var data := super.get_metrics_data()
	data["fsm_state"] = state
	data["last_transition"] = last_transition
	return data
