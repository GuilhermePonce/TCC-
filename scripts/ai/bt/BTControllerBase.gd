extends "res://scripts/ai/AIControllerBase.gd"
class_name BTControllerBase

var active_node: String = "None"
var last_tick_result: String = "IDLE"
var active_node_time: float = 0.0

func get_algorithm_name() -> String:
	return "BT"

func update_active_node_time(delta: float) -> void:
	active_node_time += delta

func succeed(node_name: String) -> void:
	if active_node != node_name:
		active_node = node_name
		active_node_time = 0.0
	last_tick_result = "SUCCESS"

func get_debug_state() -> String:
	if debug_state == "Dead" or debug_state == "Dorothy is down" or debug_state == "No active player target" or debug_state.begins_with("Fallback:"):
		return debug_state
	return "BT Active Node: %s | Last Tick Result: %s" % [active_node, last_tick_result]

func get_metrics_data() -> Dictionary:
	var data := super.get_metrics_data()
	data["bt_active_node"] = active_node
	data["last_tick_result"] = last_tick_result
	return data
