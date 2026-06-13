extends Node
class_name DecisionManager

signal decision_applied(decision_data: Dictionary)

var stats_manager: CharacterStatsManager
var metrics_logger: MetricsLogger
var current_scenario_data: Dictionary = {}

func setup(p_stats_manager: CharacterStatsManager, p_metrics_logger: MetricsLogger) -> void:
	stats_manager = p_stats_manager
	metrics_logger = p_metrics_logger

func set_current_scenario(scenario_data: Dictionary) -> void:
	current_scenario_data = scenario_data

func apply_decision(decision_data: Dictionary) -> void:
	if stats_manager == null:
		push_warning("DecisionManager has no CharacterStatsManager.")
		return

	var effects: Dictionary = decision_data.get("effects", {})
	for character_id in effects.keys():
		var character_effects: Dictionary = effects[character_id]
		for stat_name in character_effects.keys():
			stats_manager.add_stat(character_id, stat_name, int(character_effects[stat_name]))

	if metrics_logger:
		metrics_logger.log_decision(
			current_scenario_data,
			str(decision_data.get("text", "")),
			stats_manager.get_all_data()
		)

	decision_applied.emit(decision_data)
