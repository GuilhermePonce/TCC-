extends Node2D

const SCENARIO_BASE := preload("res://scenes/scenarios/Scenario_01.tscn")
const DOROTHY := preload("res://scenes/characters/Dorothy.tscn")
const LION := preload("res://scenes/characters/Lion.tscn")
const TIN_MAN := preload("res://scenes/characters/TinMan.tscn")
const SCARECROW := preload("res://scenes/characters/Scarecrow.tscn")
const ENEMY := preload("res://scenes/characters/Enemy.tscn")
const LionFSMControllerScript := preload("res://scripts/ai/fsm/LionFSMController.gd")
const TinManFSMControllerScript := preload("res://scripts/ai/fsm/TinManFSMController.gd")
const ScarecrowFSMControllerScript := preload("res://scripts/ai/fsm/ScarecrowFSMController.gd")
const LionBTControllerScript := preload("res://scripts/ai/bt/LionBTController.gd")
const TinManBTControllerScript := preload("res://scripts/ai/bt/TinManBTController.gd")
const ScarecrowBTControllerScript := preload("res://scripts/ai/bt/ScarecrowBTController.gd")
const LionGOAPControllerScript := preload("res://scripts/ai/goap/LionGOAPController.gd")
const TinManGOAPControllerScript := preload("res://scripts/ai/goap/TinManGOAPController.gd")
const ScarecrowGOAPControllerScript := preload("res://scripts/ai/goap/ScarecrowGOAPController.gd")

@export_enum("FSM", "BT", "GOAP") var AI_MODE: String = "GOAP"

@onready var characters: Node2D = $World/Characters
@onready var scenario_container: Node2D = $World/ScenarioContainer
@onready var stats_manager: CharacterStatsManager = $Managers/CharacterStatsManager
@onready var scenario_manager: ScenarioManager = $Managers/ScenarioManager
@onready var decision_manager: DecisionManager = $Managers/DecisionManager
@onready var metrics_logger: MetricsLogger = $Managers/MetricsLogger
@onready var decision_panel = $UI/DecisionPanel
@onready var debug_panel = $UI/DebugPanel

var current_scenario: ScenarioController
var dorothy: CharacterBody2D
var companions: Dictionary = {}
var enemies: Array[Node] = []
var is_advancing_scenario: bool = false
var unlocked_companions: Dictionary = {
	"scarecrow": false,
	"tin_man": false,
	"lion": false,
}

func _ready() -> void:
	decision_manager.setup(stats_manager, metrics_logger)
	decision_manager.decision_applied.connect(_on_decision_applied)
	decision_panel.challenge_started.connect(_on_challenge_started)
	scenario_manager.scenario_completed.connect(_on_scenario_completed)
	metrics_logger.set_context_provider(_get_metrics_context)
	metrics_logger.start_run(AI_MODE)

	debug_panel.setup(stats_manager)
	debug_panel.set_enemy_count_provider(_get_active_enemy_count)
	debug_panel.set_combat_context_provider(_get_debug_combat_context)
	debug_panel.skip_to_tests_requested.connect(_on_skip_to_tests_requested)
	debug_panel.stat_delta_requested.connect(_on_debug_stat_delta_requested)
	debug_panel.export_logs_requested.connect(_on_export_logs_requested)
	decision_panel.setup(decision_manager)
	decision_panel.hide_panel()

	_spawn_characters_once()
	_start_current_scenario()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				_set_ai_mode("FSM")
			KEY_B:
				_set_ai_mode("BT")
			KEY_G:
				_set_ai_mode("GOAP")
			KEY_9:
				_on_skip_to_tests_requested()
			KEY_1:
				_apply_debug_stat_delta("lion", "courage", -10 if event.shift_pressed else 10)
			KEY_2:
				_apply_debug_stat_delta("tin_man", "empathy", -10 if event.shift_pressed else 10)
			KEY_3:
				_apply_debug_stat_delta("scarecrow", "intelligence", -10 if event.shift_pressed else 10)

func _load_scenario_scene(scenario_data: Dictionary) -> void:
	if current_scenario and is_instance_valid(current_scenario):
		current_scenario.queue_free()

	var scenario_id: int = int(scenario_data.get("id", 1))
	var scene_path: String = "res://scenes/scenarios/Scenario_%02d.tscn" % scenario_id
	var scenario_scene: PackedScene = load(scene_path) if ResourceLoader.exists(scene_path) else SCENARIO_BASE
	current_scenario = scenario_scene.instantiate() as ScenarioController
	if current_scenario == null:
		push_error("Scenario scene does not use ScenarioController: %s" % scene_path)
		return
	scenario_container.add_child(current_scenario)
	current_scenario.decision_triggered.connect(_on_decision_triggered)
	current_scenario.challenge_triggered.connect(_on_challenge_triggered)
	current_scenario.exit_reached.connect(_on_exit_reached)

func _spawn_characters_once() -> void:
	dorothy = DOROTHY.instantiate() as CharacterBody2D
	characters.add_child(dorothy)

	companions["lion"] = _spawn_companion(LION, "lion")
	companions["lion"].follow_offset = Vector2(54, -28)

	companions["tin_man"] = _spawn_companion(TIN_MAN, "tin_man")
	companions["tin_man"].follow_offset = Vector2(-52, -10)

	companions["scarecrow"] = _spawn_companion(SCARECROW, "scarecrow")
	companions["scarecrow"].follow_offset = Vector2(-70, 44)

func _spawn_companion(scene: PackedScene, character_id: String) -> CompanionBase:
	var companion: CompanionBase = scene.instantiate() as CompanionBase
	characters.add_child(companion)
	companion.setup(stats_manager, dorothy)
	companion.set_ai_controller(_create_ai_controller(character_id))
	stats_manager.set_state(character_id, companion.get_debug_state())
	return companion

func _create_ai_controller(character_id: String):
	match AI_MODE:
		"BT":
			match character_id:
				"lion":
					return LionBTControllerScript.new()
				"tin_man":
					return TinManBTControllerScript.new()
				"scarecrow":
					return ScarecrowBTControllerScript.new()
		"GOAP":
			match character_id:
				"lion":
					return LionGOAPControllerScript.new()
				"tin_man":
					return TinManGOAPControllerScript.new()
				"scarecrow":
					return ScarecrowGOAPControllerScript.new()
		_:
			match character_id:
				"lion":
					return LionFSMControllerScript.new()
				"tin_man":
					return TinManFSMControllerScript.new()
				"scarecrow":
					return ScarecrowFSMControllerScript.new()
	return null

func _set_ai_mode(mode: String) -> void:
	AI_MODE = mode
	metrics_logger.set_algorithm(AI_MODE)
	for character_id in companions.keys():
		var companion: CompanionBase = companions[character_id]
		companion.set_ai_controller(_create_ai_controller(character_id))
		if companion.ai_controller and companion.ai_controller.has_method("on_scenario_changed"):
			companion.ai_controller.on_scenario_changed()
	debug_panel.set_algorithm_mode(AI_MODE)
	print("[AI] Mode changed to %s." % AI_MODE)

func _start_current_scenario() -> void:
	var scenario_data: Dictionary = scenario_manager.get_current_scenario_data()
	if scenario_data.is_empty():
		return

	_load_scenario_scene(scenario_data)
	decision_manager.set_current_scenario(scenario_data)
	debug_panel.set_scenario(scenario_data)
	debug_panel.set_algorithm_mode(AI_MODE)
	current_scenario.configure(scenario_data)
	_position_characters()
	_apply_active_characters(scenario_data)
	_spawn_enemies_for_scenario(scenario_data)
	metrics_logger.start_scenario(scenario_data)
	_notify_ai_scenario_changed()
	decision_panel.show_scenario(scenario_data)

func _position_characters() -> void:
	dorothy.global_position = current_scenario.get_spawn_position("dorothy")
	for character_id in companions.keys():
		var companion: Node2D = companions[character_id]
		companion.global_position = current_scenario.get_spawn_position(character_id)

func _apply_active_characters(scenario_data: Dictionary) -> void:
	var active_characters: Array = scenario_data.get("active_characters", [])
	for character_id in companions.keys():
		var is_active: bool = active_characters.is_empty() or active_characters.has(character_id)
		var companion: Node2D = companions[character_id]
		companion.visible = is_active
		companion.set_physics_process(is_active and bool(unlocked_companions.get(character_id, false)))
		_set_companion_collision_enabled(companion, is_active)

func _set_companion_collision_enabled(companion: Node2D, enabled: bool) -> void:
	var collision_shape := companion.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.set_deferred("disabled", not enabled)

func _spawn_enemies_for_scenario(scenario_data: Dictionary) -> void:
	_clear_enemies()
	var scenario_type: String = str(scenario_data.get("type", ""))
	var scenario_id: int = int(scenario_data.get("id", 0))
	var enemy_count: int = 1
	var enemy_offsets: Array[Vector2] = [Vector2.ZERO]
	match scenario_type:
		"transition":
			enemy_count = 0
		"test":
			enemy_count = 3
			enemy_offsets = [
				Vector2(-70, -60),
				Vector2(0, 0),
				Vector2(70, 60),
			]
		"final_test":
			enemy_count = 5
			enemy_offsets = [
				Vector2(-120, -90),
				Vector2(0, -60),
				Vector2(120, -20),
				Vector2(-70, 80),
				Vector2(80, 100),
			]
	if scenario_id == 2:
		enemy_count = 0

	var enemy_positions: Array[Vector2] = current_scenario.get_enemy_spawn_positions(enemy_count)
	if not enemy_positions.is_empty():
		enemy_count = enemy_positions.size()
	var base_position: Vector2 = current_scenario.get_spawn_position("enemy")
	for index in range(enemy_count):
		var enemy: EnemyController = ENEMY.instantiate() as EnemyController
		enemy.global_position = enemy_positions[index] if index < enemy_positions.size() else base_position + enemy_offsets[index % enemy_offsets.size()]
		enemy.target = dorothy
		_configure_enemy_for_scenario(enemy, scenario_id)
		characters.add_child(enemy)
		enemies.append(enemy)

func _configure_enemy_for_scenario(enemy: EnemyController, scenario_id: int) -> void:
	match scenario_id:
		5:
			enemy.radius = 24.0
			enemy.speed = 35.0
		10, 11:
			enemy.radius = 10.0
			enemy.speed = 85.0
		13:
			enemy.radius = 12.0
			enemy.speed = 95.0
		_:
			enemy.radius = 15.0
			enemy.speed = 55.0

func _clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()

func _on_decision_triggered() -> void:
	decision_panel.show_scenario(scenario_manager.get_current_scenario_data())

func _on_decision_applied(decision_data: Dictionary) -> void:
	_unlock_companion_for_current_scenario(decision_data)
	decision_panel.hide_panel()
	current_scenario.apply_decision_result(decision_data)
	current_scenario.mark_completed()
	debug_panel.refresh()

func _on_challenge_started() -> void:
	decision_panel.hide_panel()
	current_scenario.mark_completed()

func _on_challenge_triggered() -> void:
	decision_panel.hide_panel()

func _on_exit_reached() -> void:
	if is_advancing_scenario:
		return
	is_advancing_scenario = true
	call_deferred("_advance_after_exit")

func _advance_after_exit() -> void:
	scenario_manager.complete_current_scenario()
	if scenario_manager.has_next_scenario():
		scenario_manager.advance_scenario()
		_start_current_scenario()
	else:
		var json_path: String = metrics_logger.export_json()
		var run_csv_path: String = metrics_logger.export_run_summary_csv()
		print("Final scenario completed. Metrics JSON: %s" % json_path)
		print("Final scenario completed. Run Summary CSV: %s" % run_csv_path)
	is_advancing_scenario = false

func _on_scenario_completed(scenario_data: Dictionary) -> void:
	metrics_logger.end_scenario(scenario_data)

func _on_skip_to_tests_requested() -> void:
	if is_advancing_scenario:
		return
	is_advancing_scenario = true
	call_deferred("_jump_to_test_scenarios")

func _jump_to_test_scenarios() -> void:
	decision_panel.hide_panel()
	for character_id in unlocked_companions.keys():
		unlocked_companions[character_id] = true
	scenario_manager.complete_current_scenario()
	scenario_manager.jump_to_first_type("test")
	_start_current_scenario()
	is_advancing_scenario = false

func _unlock_companion_for_current_scenario(_decision_data: Dictionary) -> void:
	var scenario_id: int = int(scenario_manager.get_current_scenario_data().get("id", 0))
	match scenario_id:
		1:
			unlocked_companions["scarecrow"] = true
		2:
			unlocked_companions["tin_man"] = true
		3:
			unlocked_companions["lion"] = true
	_apply_active_characters(scenario_manager.get_current_scenario_data())

func _on_debug_stat_delta_requested(character_id: String, stat_name: String, delta: int) -> void:
	_apply_debug_stat_delta(character_id, stat_name, delta)

func _on_export_logs_requested() -> void:
	var json_path: String = metrics_logger.export_json()
	var run_csv_path: String = metrics_logger.export_run_summary_csv()
	print("Metrics JSON exported from DebugPanel: %s" % json_path)
	print("Metrics Run Summary CSV exported from DebugPanel: %s" % run_csv_path)

func _apply_debug_stat_delta(character_id: String, stat_name: String, delta: int) -> void:
	stats_manager.add_stat(character_id, stat_name, delta)
	debug_panel.refresh()

func _notify_ai_scenario_changed() -> void:
	for character_id in companions.keys():
		var companion: CompanionBase = companions[character_id]
		if is_instance_valid(companion):
			companion.follow_target = dorothy
			companion.attack_timer = 0.0
			if companion.ai_controller and companion.ai_controller.has_method("on_scenario_changed"):
				companion.ai_controller.on_scenario_changed()

func _get_active_enemy_count() -> int:
	var active_count: int = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree() and _is_combatant_alive(enemy):
			active_count += 1
	return active_count

func _get_metrics_context() -> Dictionary:
	var npc_debug_states: Dictionary = {}
	var npc_ai_metrics: Dictionary = {}
	for character_id in companions.keys():
		var companion = companions[character_id]
		if is_instance_valid(companion) and companion.has_method("get_debug_state"):
			npc_debug_states[character_id] = companion.get_debug_state()
			if companion.ai_controller and companion.ai_controller.has_method("get_metrics_data"):
				npc_ai_metrics[character_id] = companion.ai_controller.get_metrics_data()
	return {
		"algorithm_mode": AI_MODE,
		"npc_debug_states": npc_debug_states,
		"npc_ai_metrics": npc_ai_metrics,
		"active_enemy_count": _get_active_enemy_count(),
		"combat": _get_debug_combat_context(),
		"character_snapshot": _get_character_snapshot(),
	}

func _get_character_snapshot() -> Dictionary:
	var combat: Dictionary = _get_debug_combat_context()
	var lion_summary: Dictionary = combat.get("lion", {})
	var tin_man_summary: Dictionary = combat.get("tin_man", {})
	var scarecrow_summary: Dictionary = combat.get("scarecrow", {})
	var dorothy_summary: Dictionary = combat.get("dorothy", {})
	return {
		"lion": {
			"courage": stats_manager.get_stat("lion", "courage"),
			"health": int(lion_summary.get("hp", 0)),
			"damage": int(lion_summary.get("damage", 0)),
		},
		"tin_man": {
			"empathy": stats_manager.get_stat("tin_man", "empathy"),
			"health": int(tin_man_summary.get("hp", 0)),
			"damage": int(tin_man_summary.get("damage", 0)),
		},
		"scarecrow": {
			"intelligence": stats_manager.get_stat("scarecrow", "intelligence"),
			"health": int(scarecrow_summary.get("hp", 0)),
			"damage": int(scarecrow_summary.get("damage", 0)),
		},
		"dorothy": {
			"health": int(dorothy_summary.get("hp", 0)),
			"damage": int(dorothy_summary.get("damage", 0)),
		},
	}

func _get_debug_combat_context() -> Dictionary:
	var enemy_damage_values: Array[int] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and _is_combatant_alive(enemy):
			var enemy_stats := enemy.get_node_or_null("CombatStats") as CombatStats
			if enemy_stats:
				enemy_damage_values.append(enemy_stats.current_damage)
	return {
		"dorothy": _get_combat_summary(dorothy),
		"lion": _get_combat_summary(companions.get("lion")),
		"tin_man": _get_combat_summary(companions.get("tin_man")),
		"scarecrow": _get_combat_summary(companions.get("scarecrow")),
		"enemy_avg_damage": _get_average_int(enemy_damage_values),
		"dorothy_attack": dorothy.get_attack_state_text() if is_instance_valid(dorothy) and dorothy.has_method("get_attack_state_text") else "",
	}

func _get_combat_summary(node) -> Dictionary:
	if not is_instance_valid(node):
		return {"hp": 0, "max_hp": 0, "damage": 0, "alive": false}
	var combat_stats := node.get_node_or_null("CombatStats") as CombatStats
	if combat_stats == null:
		return {"hp": 0, "max_hp": 0, "damage": 0, "alive": false}
	return {
		"hp": combat_stats.current_health,
		"max_hp": combat_stats.max_health,
		"damage": combat_stats.current_damage,
		"alive": combat_stats.is_alive,
	}

func _is_combatant_alive(node: Node) -> bool:
	var combat_stats := node.get_node_or_null("CombatStats") as CombatStats
	return combat_stats != null and combat_stats.is_alive

func _get_average_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var total: int = 0
	for value in values:
		total += value
	return int(round(float(total) / float(values.size())))
