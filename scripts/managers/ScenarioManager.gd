extends Node
class_name ScenarioManager

signal scenario_loaded(scenario_data: Dictionary)
signal scenario_completed(scenario_data: Dictionary)

const SCENARIOS_PATH := "res://data/scenarios.json"

var scenarios: Array = []
var current_index: int = 0

func _ready() -> void:
	load_scenarios()

func load_scenarios() -> void:
	var file: FileAccess = FileAccess.open(SCENARIOS_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open scenarios data: %s" % SCENARIOS_PATH)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid scenarios data. Expected an array.")
		return

	scenarios = parsed
	current_index = 0

func get_current_scenario_data() -> Dictionary:
	if current_index < 0 or current_index >= scenarios.size():
		return {}
	return scenarios[current_index]

func emit_current_scenario() -> void:
	var scenario_data: Dictionary = get_current_scenario_data()
	if not scenario_data.is_empty():
		scenario_loaded.emit(scenario_data)

func complete_current_scenario() -> void:
	scenario_completed.emit(get_current_scenario_data())

func has_next_scenario() -> bool:
	return current_index + 1 < scenarios.size()

func advance_scenario() -> Dictionary:
	if has_next_scenario():
		current_index += 1
	emit_current_scenario()
	return get_current_scenario_data()

func jump_to_first_type(scenario_type: String) -> Dictionary:
	for index in range(scenarios.size()):
		var scenario_data: Dictionary = scenarios[index]
		if str(scenario_data.get("type", "")) == scenario_type:
			current_index = index
			emit_current_scenario()
			return scenario_data
	return get_current_scenario_data()

func scenario_requires_decision(scenario_data: Dictionary) -> bool:
	var scenario_type: String = str(scenario_data.get("type", ""))
	return scenario_type == "calibration" or scenario_type == "transition"
