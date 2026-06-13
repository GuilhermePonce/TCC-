extends Node
class_name MetricsLogger

const CSV_SUMMARY_HEADER: Array[String] = [
	"run_id",
	"algorithm",
	"scenario_id",
	"scenario_name",
	"scenario_type",
	"duration_seconds",
	"decision",
	"lion_courage",
	"tin_man_empathy",
	"scarecrow_intelligence",
	"dorothy_hp",
	"lion_hp",
	"tin_man_hp",
	"scarecrow_hp",
	"dorothy_damage_current",
	"lion_damage_current",
	"tin_man_damage_current",
	"scarecrow_damage_current",
	"lion_damage_dealt",
	"tin_man_healing_done",
	"scarecrow_buffs_applied",
	"scarecrow_debuffs_applied",
	"dorothy_damage_dealt",
	"enemy_damage_dealt",
	"enemy_kills",
	"avg_decision_time_lion_usec",
	"avg_decision_time_tin_man_usec",
	"avg_decision_time_scarecrow_usec",
	"max_decision_time_lion_usec",
	"max_decision_time_tin_man_usec",
	"max_decision_time_scarecrow_usec",
]

const RUN_SUMMARY_CSV_HEADER: Array[String] = [
	"run_id",
	"algorithm",
	"duration_seconds",
	"total_scenarios_completed",
	"total_decisions_made",
	"total_ai_decision_samples",
	"total_decision_time_usec",
	"avg_decision_time_usec",
	"max_decision_time_usec",
	"avg_memory_mb",
	"max_memory_mb",
	"final_memory_mb",
	"total_behavior_changes",
	"fsm_state_changes",
	"bt_node_changes",
	"goap_goal_changes",
	"goap_plan_changes",
	"goap_replans",
	"total_damage_dealt",
	"total_healing_done",
	"total_enemy_kills",
]

var run_data: Dictionary = {}
var context_provider: Callable
var current_scenario: Dictionary = {}
var current_scenario_started_at_msec: int = 0
var run_started_at_msec: int = 0
var ai_decision_samples: Dictionary = {}
var last_ai_states: Dictionary = {}
var run_decision_samples: Dictionary = {}
var memory_samples: Array[float] = []
var final_memory_mb: float = 0.0
var behavior_change_counts: Dictionary = {}
var goap_replans: int = 0
var run_id_locked: bool = false

func _ready() -> void:
	add_to_group("metrics_logger")

func set_context_provider(provider: Callable) -> void:
	context_provider = provider

func start_run(algorithm: String) -> void:
	run_started_at_msec = Time.get_ticks_msec()
	run_decision_samples.clear()
	memory_samples.clear()
	final_memory_mb = 0.0
	run_id_locked = false
	behavior_change_counts = {
		"fsm_state_changes": 0,
		"bt_node_changes": 0,
		"goap_goal_changes": 0,
		"goap_plan_changes": 0,
	}
	goap_replans = 0
	var start_time: String = Time.get_datetime_string_from_system()
	run_data = {
		"run_id": _build_run_id(algorithm),
		"algorithm": algorithm,
		"start_time": start_time,
		"end_time": "",
		"duration_seconds": 0.0,
		"scenarios": [],
		"summary": {
			"total_damage_dealt": 0,
			"total_healing_done": 0,
			"total_enemy_kills": 0,
			"total_decisions_made": 0,
			"total_scenarios_completed": 0,
		},
	}
	_sample_memory()

func set_algorithm(algorithm: String) -> void:
	if run_data.is_empty():
		start_run(algorithm)
	else:
		run_data["algorithm"] = algorithm

func start_scenario(scenario_data: Dictionary) -> void:
	if run_data.is_empty():
		start_run(str(_get_runtime_context().get("algorithm_mode", "FSM")))

	current_scenario_started_at_msec = Time.get_ticks_msec()
	ai_decision_samples.clear()
	last_ai_states.clear()
	current_scenario = {
		"scenario_id": int(scenario_data.get("id", 0)),
		"scenario_name": str(scenario_data.get("name", "")),
		"scenario_type": str(scenario_data.get("type", "")),
		"start_time": Time.get_datetime_string_from_system(),
		"end_time": "",
		"duration_seconds": 0.0,
		"decision": "",
		"characters": {},
		"events": [],
		"decision_time_stats": {},
		"combat_stats": {
			"lion_damage_dealt": 0,
			"tin_man_healing_done": 0,
			"scarecrow_buffs_applied": 0,
			"scarecrow_debuffs_applied": 0,
			"dorothy_damage_dealt": 0,
			"enemy_damage_dealt": 0,
			"enemy_kills": 0,
		},
	}
	print("[MetricsLogger] start_scenario ", current_scenario["scenario_name"])

func log_decision(scenario_data: Dictionary, decision_text: String, stats_after: Dictionary) -> void:
	if current_scenario.is_empty():
		start_scenario(scenario_data)
	current_scenario["decision"] = decision_text
	run_data["summary"]["total_decisions_made"] += 1
	_add_event({
		"event": "decision",
		"decision": decision_text,
		"stats_after": stats_after,
	})

func end_scenario(scenario_data: Dictionary) -> void:
	if current_scenario.is_empty():
		start_scenario(scenario_data)

	var ended_at_msec: int = Time.get_ticks_msec()
	current_scenario["end_time"] = Time.get_datetime_string_from_system()
	current_scenario["duration_seconds"] = float(ended_at_msec - current_scenario_started_at_msec) / 1000.0
	current_scenario["characters"] = _get_character_snapshot()
	current_scenario["decision_time_stats"] = _build_decision_time_stats()
	run_data["scenarios"].append(current_scenario.duplicate(true))
	run_data["summary"]["total_scenarios_completed"] += 1
	current_scenario.clear()
	print("[MetricsLogger] end_scenario ", str(scenario_data.get("name", "")))

func log_combat_event(event_name: String, payload: Dictionary) -> void:
	var normalized: Dictionary = _normalize_combat_event(event_name, payload)
	_add_event(normalized)
	_update_combat_aggregates(normalized)
	print("[MetricsLogger] ", normalized)

func log_edge_event(event_name: String, payload: Dictionary = {}) -> void:
	var event := payload.duplicate(true)
	event["event"] = event_name
	_add_event(event)
	if event_name == "plan_invalidated":
		goap_replans += 1
	print("[MetricsLogger] ", event)

func log_ai_update(payload: Dictionary) -> void:
	var npc_id: String = str(payload.get("npc_id", ""))
	var algorithm: String = str(payload.get("algorithm", ""))
	var decision_time_usec: int = int(payload.get("last_decision_time_usec", 0))
	if not ai_decision_samples.has(npc_id):
		ai_decision_samples[npc_id] = []
	ai_decision_samples[npc_id].append(decision_time_usec)
	if not run_decision_samples.has(npc_id):
		run_decision_samples[npc_id] = []
	run_decision_samples[npc_id].append(decision_time_usec)
	_sample_memory()

	match algorithm:
		"FSM":
			_log_state_change_if_needed(npc_id, payload)
		"BT":
			_log_bt_node_if_needed(npc_id, payload)
		"GOAP":
			_log_goap_if_needed(npc_id, payload)

func export_json() -> String:
	if run_data.is_empty():
		start_run("FSM")

	var export_data: Dictionary = _build_run_summary_export_data()
	var path: String = _get_metrics_export_path(".json")
	if path.is_empty():
		return ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not export metrics JSON to %s" % path)
		return ""
	file.store_string(JSON.stringify(export_data, "\t"))
	file.close()
	print("JSON exported: %s" % path)
	return path

func export_csv_summary() -> String:
	if run_data.is_empty():
		start_run("FSM")

	var export_data: Dictionary = _build_export_data()
	var path: String = _get_metrics_export_path("_summary.csv")
	if path.is_empty():
		return ""

	var lines := PackedStringArray()
	lines.append(",".join(_get_csv_summary_header_values()))
	for scenario in export_data.get("scenarios", []):
		lines.append(_build_csv_summary_row(export_data, scenario))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not export CSV summary to %s" % path)
		return ""
	file.store_string("\n".join(lines))
	file.close()
	print("CSV summary exported: %s" % path)
	return path

func export_run_summary_csv() -> String:
	if run_data.is_empty():
		start_run("FSM")

	var export_data: Dictionary = _build_export_data()
	var path: String = _get_metrics_export_path("_run_summary.csv")
	if path.is_empty():
		return ""

	var lines := PackedStringArray()
	lines.append(",".join(_get_run_summary_header_values()))
	lines.append(_build_run_summary_csv_row(export_data))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not export run summary CSV to %s" % path)
		return ""
	file.store_string("\n".join(lines))
	file.close()
	print("Run summary CSV exported: %s" % path)
	return path

func csv_escape(value) -> String:
	var text: String = str(value)
	var must_quote: bool = text.contains(",") or text.contains("\"") or text.contains("\n") or text.contains("\r")
	text = text.replace("\"", "\"\"")
	return "\"%s\"" % text if must_quote else text

func _get_csv_summary_header_values() -> PackedStringArray:
	var header_values := PackedStringArray()
	for column in CSV_SUMMARY_HEADER:
		header_values.append(column)
	return header_values

func _get_run_summary_header_values() -> PackedStringArray:
	var header_values := PackedStringArray()
	for column in RUN_SUMMARY_CSV_HEADER:
		header_values.append(column)
	return header_values

func _build_csv_summary_row(export_data: Dictionary, scenario_value) -> String:
	var scenario: Dictionary = _as_dictionary(scenario_value)
	var characters: Dictionary = _as_dictionary(scenario.get("characters", {}))
	var combat_stats: Dictionary = _as_dictionary(scenario.get("combat_stats", {}))
	var decision_time_stats: Dictionary = _as_dictionary(scenario.get("decision_time_stats", {}))
	var dorothy: Dictionary = _as_dictionary(characters.get("dorothy", {}))
	var lion: Dictionary = _as_dictionary(characters.get("lion", {}))
	var tin_man: Dictionary = _as_dictionary(characters.get("tin_man", {}))
	var scarecrow: Dictionary = _as_dictionary(characters.get("scarecrow", {}))
	var lion_decision: Dictionary = _as_dictionary(decision_time_stats.get("lion", {}))
	var tin_man_decision: Dictionary = _as_dictionary(decision_time_stats.get("tin_man", {}))
	var scarecrow_decision: Dictionary = _as_dictionary(decision_time_stats.get("scarecrow", {}))

	var values: Array = [
		str(export_data.get("run_id", "")),
		str(export_data.get("algorithm", "")),
		int(scenario.get("scenario_id", 0)),
		str(scenario.get("scenario_name", "")),
		str(scenario.get("scenario_type", "")),
		float(scenario.get("duration_seconds", 0.0)),
		str(scenario.get("decision", "")),
		int(lion.get("courage", 0)),
		int(tin_man.get("empathy", 0)),
		int(scarecrow.get("intelligence", 0)),
		int(dorothy.get("health", 0)),
		int(lion.get("health", 0)),
		int(tin_man.get("health", 0)),
		int(scarecrow.get("health", 0)),
		int(dorothy.get("damage", 0)),
		int(lion.get("damage", 0)),
		int(tin_man.get("damage", 0)),
		int(scarecrow.get("damage", 0)),
		int(combat_stats.get("lion_damage_dealt", 0)),
		int(combat_stats.get("tin_man_healing_done", 0)),
		int(combat_stats.get("scarecrow_buffs_applied", 0)),
		int(combat_stats.get("scarecrow_debuffs_applied", 0)),
		int(combat_stats.get("dorothy_damage_dealt", 0)),
		int(combat_stats.get("enemy_damage_dealt", 0)),
		int(combat_stats.get("enemy_kills", 0)),
		int(lion_decision.get("avg_decision_time_usec", 0)),
		int(tin_man_decision.get("avg_decision_time_usec", 0)),
		int(scarecrow_decision.get("avg_decision_time_usec", 0)),
		int(lion_decision.get("max_decision_time_usec", 0)),
		int(tin_man_decision.get("max_decision_time_usec", 0)),
		int(scarecrow_decision.get("max_decision_time_usec", 0)),
	]
	var escaped_values := PackedStringArray()
	for value in values:
		escaped_values.append(csv_escape(value))
	return ",".join(escaped_values)

func _build_run_summary_csv_row(export_data: Dictionary) -> String:
	var summary: Dictionary = _as_dictionary(export_data.get("summary", {}))
	var decision_stats: Dictionary = _as_dictionary(summary.get("decision_time", {}))
	var memory_stats: Dictionary = _as_dictionary(summary.get("memory", {}))
	var behavior_stats: Dictionary = _as_dictionary(summary.get("behavior_changes", {}))
	var combat_stats: Dictionary = _as_dictionary(summary.get("combat", {}))
	var values: Array = [
		str(export_data.get("run_id", "")),
		str(export_data.get("algorithm", "")),
		float(export_data.get("duration_seconds", 0.0)),
		int(summary.get("total_scenarios_completed", 0)),
		int(summary.get("total_decisions_made", 0)),
		int(decision_stats.get("sample_count", 0)),
		int(decision_stats.get("total_decision_time_usec", 0)),
		int(decision_stats.get("avg_decision_time_usec", 0)),
		int(decision_stats.get("max_decision_time_usec", 0)),
		float(memory_stats.get("avg_memory_mb", 0.0)),
		float(memory_stats.get("max_memory_mb", 0.0)),
		float(memory_stats.get("final_memory_mb", 0.0)),
		int(behavior_stats.get("total_behavior_changes", 0)),
		int(behavior_stats.get("fsm_state_changes", 0)),
		int(behavior_stats.get("bt_node_changes", 0)),
		int(behavior_stats.get("goap_goal_changes", 0)),
		int(behavior_stats.get("goap_plan_changes", 0)),
		int(summary.get("goap_replans", 0)),
		int(combat_stats.get("total_damage_dealt", 0)),
		int(combat_stats.get("total_healing_done", 0)),
		int(combat_stats.get("total_enemy_kills", 0)),
	]
	var escaped_values := PackedStringArray()
	for value in values:
		escaped_values.append(csv_escape(value))
	return ",".join(escaped_values)

func _build_export_data() -> Dictionary:
	_ensure_export_run_id()
	run_data["end_time"] = Time.get_datetime_string_from_system()
	run_data["duration_seconds"] = float(Time.get_ticks_msec() - run_started_at_msec) / 1000.0
	_sample_memory()
	_rebuild_summary_totals(run_data)

	var export_data: Dictionary = run_data.duplicate(true)
	return export_data

func _build_run_summary_export_data() -> Dictionary:
	_build_export_data()
	var summary: Dictionary = run_data["summary"].duplicate(true)
	summary["run_id"] = run_data.get("run_id", "")
	summary["algorithm"] = run_data.get("algorithm", "")
	summary["start_time"] = run_data.get("start_time", "")
	summary["end_time"] = run_data.get("end_time", "")
	summary["duration_seconds"] = run_data.get("duration_seconds", 0.0)
	return {
		"summary": summary,
	}

func _get_metrics_export_path(suffix: String) -> String:
	var algorithm_dir: String = str(run_data.get("algorithm", "FSM")).to_lower()
	var relative_dir: String = "logs/%s" % algorithm_dir
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		push_error("Could not open user:// to export metrics.")
		return ""
	var dir_error: int = user_dir.make_dir_recursive(relative_dir)
	if dir_error != OK:
		push_error("Could not create metrics directory user://%s" % relative_dir)
		return ""
	return "user://%s/%s%s" % [relative_dir, str(run_data.get("run_id", "run")), suffix]

func _ensure_export_run_id() -> void:
	if run_id_locked:
		return
	run_data["run_id"] = _build_run_id(str(run_data.get("algorithm", "FSM")))
	run_id_locked = true

func _add_event(event_data: Dictionary) -> void:
	if current_scenario.is_empty():
		return
	var event := event_data.duplicate(true)
	event["timestamp"] = _scenario_timestamp_seconds()
	current_scenario["events"].append(event)

func _normalize_combat_event(event_name: String, payload: Dictionary) -> Dictionary:
	match event_name:
		"damage_dealt":
			return {
				"event": "attack",
				"source": str(payload.get("source", "")),
				"target": str(payload.get("target", "")),
				"value": int(payload.get("amount", 0)),
			}
		"enemy_damage_dealt":
			return {
				"event": "attack",
				"source": "enemy",
				"target": str(payload.get("target", "")),
				"value": int(payload.get("amount", 0)),
			}
		"healing_done":
			return {
				"event": "heal",
				"source": str(payload.get("source", "")),
				"target": str(payload.get("target", "")),
				"value": int(payload.get("amount", 0)),
			}
		"enemy_died":
			return {
				"event": "death",
				"source": str(payload.get("source", "enemy")),
				"target": "enemy",
				"value": 1,
			}
		"scarecrow_modifiers_applied":
			var allies_buffed = payload.get("allies_buffed", [])
			var is_buff: bool = int(payload.get("enemies_weakened", 0)) > 0 or _has_any_items(allies_buffed)
			return {
				"event": "buff" if is_buff else "debuff",
				"source": str(payload.get("source", "scarecrow")),
				"target": "group",
				"value": 1,
				"details": payload.duplicate(true),
			}
	return {
		"event": event_name,
		"source": str(payload.get("source", "")),
		"target": str(payload.get("target", "")),
		"value": int(payload.get("amount", payload.get("value", 0))),
		"details": payload.duplicate(true),
	}

func _update_combat_aggregates(event: Dictionary) -> void:
	if current_scenario.is_empty():
		return
	var combat_stats: Dictionary = current_scenario["combat_stats"]
	var summary: Dictionary = run_data["summary"]
	var event_type: String = str(event.get("event", ""))
	var source: String = str(event.get("source", ""))
	var value: int = int(event.get("value", 0))

	if event_type == "attack":
		summary["total_damage_dealt"] += value
		match source:
			"dorothy":
				combat_stats["dorothy_damage_dealt"] += value
			"lion":
				combat_stats["lion_damage_dealt"] += value
			"enemy":
				combat_stats["enemy_damage_dealt"] += value
	elif event_type == "heal":
		summary["total_healing_done"] += value
		if source == "tin_man":
			combat_stats["tin_man_healing_done"] += value
	elif event_type == "death":
		summary["total_enemy_kills"] += 1
		combat_stats["enemy_kills"] += 1
	elif source == "scarecrow" and event.has("details"):
		var details: Dictionary = event["details"]
		if _has_any_items(details.get("allies_buffed", [])) or int(details.get("enemies_strengthened", 0)) > 0:
			combat_stats["scarecrow_buffs_applied"] += 1
		if _has_any_items(details.get("allies_harmed", [])) or int(details.get("enemies_weakened", 0)) > 0:
			combat_stats["scarecrow_debuffs_applied"] += 1
	elif event_type == "buff":
		combat_stats["scarecrow_buffs_applied"] += 1
	elif event_type == "debuff":
		combat_stats["scarecrow_debuffs_applied"] += 1

func _log_state_change_if_needed(npc_id: String, payload: Dictionary) -> void:
	var current_state: String = str(payload.get("fsm_state", ""))
	var key: String = "%s_state" % npc_id
	if str(last_ai_states.get(key, "")) == current_state:
		return
	var previous_state: String = str(last_ai_states.get(key, ""))
	last_ai_states[key] = current_state
	if not previous_state.is_empty():
		behavior_change_counts["fsm_state_changes"] += 1
	_add_event({
		"event": "state_change",
		"npc": npc_id,
		"from": previous_state,
		"to": current_state,
	})

func _log_bt_node_if_needed(npc_id: String, payload: Dictionary) -> void:
	var active_node: String = str(payload.get("bt_active_node", ""))
	var key: String = "%s_bt_node" % npc_id
	if str(last_ai_states.get(key, "")) == active_node:
		return
	var previous_node: String = str(last_ai_states.get(key, ""))
	last_ai_states[key] = active_node
	if not previous_node.is_empty():
		behavior_change_counts["bt_node_changes"] += 1
	_add_event({
		"event": "bt_node",
		"npc": npc_id,
		"node": active_node,
		"result": str(payload.get("last_tick_result", "")),
	})

func _log_goap_if_needed(npc_id: String, payload: Dictionary) -> void:
	var goal: String = str(payload.get("goap_goal", ""))
	var goal_key: String = "%s_goap_goal" % npc_id
	if str(last_ai_states.get(goal_key, "")) != goal:
		var previous_goal: String = str(last_ai_states.get(goal_key, ""))
		last_ai_states[goal_key] = goal
		if not previous_goal.is_empty():
			behavior_change_counts["goap_goal_changes"] += 1
		_add_event({
			"event": "goal_change",
			"npc": npc_id,
			"goal": goal,
		})

	var plan: Array = payload.get("goap_plan", [])
	var plan_key: String = "%s_goap_plan" % npc_id
	var plan_names := PackedStringArray()
	for step in plan:
		plan_names.append(str(step))
	var plan_text: String = " -> ".join(plan_names)
	if str(last_ai_states.get(plan_key, "")) == plan_text:
		return
	var previous_plan: String = str(last_ai_states.get(plan_key, ""))
	last_ai_states[plan_key] = plan_text
	if not previous_plan.is_empty():
		behavior_change_counts["goap_plan_changes"] += 1
	_add_event({
		"event": "plan_created",
		"npc": npc_id,
		"plan": plan.duplicate(true),
		"cost": int(payload.get("plan_cost", 0)),
	})

func _build_decision_time_stats() -> Dictionary:
	var output: Dictionary = {}
	for npc_id in ai_decision_samples.keys():
		var samples: Array = ai_decision_samples[npc_id]
		if samples.is_empty():
			continue
		var total: int = 0
		var max_value: int = 0
		for sample in samples:
			var value: int = int(sample)
			total += value
			max_value = maxi(max_value, value)
		output[npc_id] = {
			"avg_decision_time_usec": int(round(float(total) / float(samples.size()))),
			"max_decision_time_usec": max_value,
		}
	return output

func _build_run_decision_time_summary() -> Dictionary:
	var total: int = 0
	var max_value: int = 0
	var sample_count: int = 0
	var by_npc: Dictionary = {}
	for npc_id in run_decision_samples.keys():
		var samples: Array = run_decision_samples[npc_id]
		var npc_total: int = 0
		var npc_max: int = 0
		for sample in samples:
			var value: int = int(sample)
			npc_total += value
			npc_max = maxi(npc_max, value)
			total += value
			max_value = maxi(max_value, value)
			sample_count += 1
		by_npc[npc_id] = {
			"sample_count": samples.size(),
			"total_decision_time_usec": npc_total,
			"avg_decision_time_usec": int(round(float(npc_total) / float(samples.size()))) if not samples.is_empty() else 0,
			"max_decision_time_usec": npc_max,
		}
	return {
		"sample_count": sample_count,
		"total_decision_time_usec": total,
		"avg_decision_time_usec": int(round(float(total) / float(sample_count))) if sample_count > 0 else 0,
		"max_decision_time_usec": max_value,
		"by_npc": by_npc,
	}

func _build_memory_summary() -> Dictionary:
	if memory_samples.is_empty():
		return {
			"sample_count": 0,
			"avg_memory_mb": 0.0,
			"max_memory_mb": 0.0,
			"final_memory_mb": 0.0,
		}
	var total: float = 0.0
	var max_value: float = 0.0
	for sample in memory_samples:
		total += sample
		max_value = maxf(max_value, sample)
	return {
		"sample_count": memory_samples.size(),
		"avg_memory_mb": snappedf(total / float(memory_samples.size()), 0.001),
		"max_memory_mb": snappedf(max_value, 0.001),
		"final_memory_mb": snappedf(final_memory_mb, 0.001),
	}

func _build_behavior_change_summary() -> Dictionary:
	var fsm_count: int = int(behavior_change_counts.get("fsm_state_changes", 0))
	var bt_count: int = int(behavior_change_counts.get("bt_node_changes", 0))
	var goap_goal_count: int = int(behavior_change_counts.get("goap_goal_changes", 0))
	var goap_plan_count: int = int(behavior_change_counts.get("goap_plan_changes", 0))
	return {
		"total_behavior_changes": fsm_count + bt_count + goap_goal_count + goap_plan_count,
		"fsm_state_changes": fsm_count,
		"bt_node_changes": bt_count,
		"goap_goal_changes": goap_goal_count,
		"goap_plan_changes": goap_plan_count,
	}

func _sample_memory() -> void:
	var memory_mb: float = float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	final_memory_mb = memory_mb
	memory_samples.append(memory_mb)

func _get_character_snapshot() -> Dictionary:
	var context: Dictionary = _get_runtime_context()
	if context.has("character_snapshot"):
		return context["character_snapshot"]
	return {}

func _as_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return value
	return {}

func _has_any_items(value) -> bool:
	if value is Array or value is PackedStringArray:
		return not value.is_empty()
	return false

func _get_runtime_context() -> Dictionary:
	if context_provider.is_valid():
		return context_provider.call()
	return {}

func _scenario_timestamp_seconds() -> float:
	return float(Time.get_ticks_msec() - current_scenario_started_at_msec) / 1000.0

func _build_run_id(algorithm: String) -> String:
	var algorithm_dir: String = str(algorithm).to_lower()
	var relative_dir: String = "logs/%s" % algorithm_dir
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		return "run_1"
	user_dir.make_dir_recursive(relative_dir)

	var logs_dir := DirAccess.open("user://%s" % relative_dir)
	if logs_dir == null:
		return "run_1"

	var highest_run_number: int = 0
	logs_dir.list_dir_begin()
	var file_name: String = logs_dir.get_next()
	while not file_name.is_empty():
		if not logs_dir.current_is_dir():
			highest_run_number = maxi(highest_run_number, _extract_run_number(file_name))
		file_name = logs_dir.get_next()
	logs_dir.list_dir_end()
	return "run_%s" % (highest_run_number + 1)

func _extract_run_number(file_name: String) -> int:
	if not file_name.begins_with("run_"):
		return 0
	var number_text: String = ""
	var index: int = 4
	while index < file_name.length():
		var character: String = file_name.substr(index, 1)
		if not character.is_valid_int():
			break
		number_text += character
		index += 1
	if number_text.is_empty():
		return 0
	var suffix: String = file_name.substr(index)
	if suffix != ".json" and suffix != "_run_summary.csv" and suffix != "_summary.csv":
		return 0
	return int(number_text) if not number_text.is_empty() else 0

func _rebuild_summary_totals(data: Dictionary) -> void:
	var summary: Dictionary = data["summary"]
	summary["total_scenarios_completed"] = data["scenarios"].size()
	summary["decision_time"] = _build_run_decision_time_summary()
	summary["memory"] = _build_memory_summary()
	summary["behavior_changes"] = _build_behavior_change_summary()
	summary["goap_replans"] = goap_replans
	summary["combat"] = {
		"total_damage_dealt": int(summary.get("total_damage_dealt", 0)),
		"total_healing_done": int(summary.get("total_healing_done", 0)),
		"total_enemy_kills": int(summary.get("total_enemy_kills", 0)),
	}
