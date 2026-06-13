extends RefCounted
class_name AIControllerBase

var companion: CompanionBase
var dorothy: Node2D
var stats_manager: CharacterStatsManager
var combat_stats: CombatStats
var metrics_logger
var debug_state: String = "None"
var last_decision_time_usec: int = 0
var support_action_timer: float = 0.0
var support_action_cooldown: float = 0.9
var stuck_timer: float = 0.0
var stuck_timeout: float = 2.5
var stuck_min_progress: float = 4.0
var last_distance_to_target: float = INF
var last_move_target: Vector2 = Vector2(INF, INF)
var edge_events_logged: Dictionary = {}
var last_ai_delta: float = 0.0

func setup(p_companion, p_stats_manager, p_combat_stats = null, p_metrics_logger = null) -> void:
	companion = p_companion
	dorothy = companion.get_tree().get_first_node_in_group("player") as Node2D
	stats_manager = p_stats_manager
	combat_stats = p_combat_stats if p_combat_stats != null else companion.combat_stats
	metrics_logger = p_metrics_logger

func update_ai(_delta: float) -> void:
	pass

func begin_ai_update(delta: float) -> bool:
	last_ai_delta = delta
	support_action_timer = maxf(support_action_timer - delta, 0.0)
	if not is_valid_living_target(companion):
		debug_state = "Dead"
		_stop_companion()
		_log_edge_event_once("npc_dead", {"npc": _npc_id()})
		return false
	if not is_dorothy_available():
		debug_state = "Dorothy is down"
		_stop_companion()
		_log_edge_event_once("dorothy_down", {"npc": _npc_id(), "reason": "no_active_player_target"})
		return false
	if debug_state == "Dead" or debug_state == "Dorothy is down" or debug_state == "No active player target" or debug_state.begins_with("Fallback:"):
		debug_state = "None"
	return true

func update_action_timers(delta: float) -> void:
	support_action_timer = maxf(support_action_timer - delta, 0.0)

func on_scenario_changed() -> void:
	if companion:
		dorothy = companion.get_tree().get_first_node_in_group("player") as Node2D
	else:
		dorothy = null
	support_action_timer = 0.0
	stuck_timer = 0.0
	last_distance_to_target = INF
	last_move_target = Vector2(INF, INF)
	edge_events_logged.clear()
	_log_edge_event("scenario_reference_reset", {"npc": _npc_id()})

func get_debug_state() -> String:
	return debug_state

func get_algorithm_name() -> String:
	return "Base"

func get_metrics_data() -> Dictionary:
	var data: Dictionary = {
		"algorithm": get_algorithm_name(),
		"debug_state": get_debug_state(),
		"last_decision_time_usec": last_decision_time_usec,
	}
	if companion and companion.character_id == "scarecrow":
		data["intelligence"] = get_stat_value()
	return data

func _measure_start() -> int:
	return Time.get_ticks_usec()

func _measure_end(start_usec: int) -> void:
	last_decision_time_usec = Time.get_ticks_usec() - start_usec

func get_stat_value() -> int:
	if companion == null or stats_manager == null:
		return 0
	return stats_manager.get_stat(companion.character_id, companion.main_stat_name)

func get_character_stat(character_id: String, stat_name: String) -> int:
	if stats_manager == null:
		return 0
	return stats_manager.get_stat(character_id, stat_name)

func follow_dorothy() -> void:
	if not is_dorothy_available():
		debug_state = "No active player target"
		companion.velocity = Vector2.ZERO
		companion.move_and_slide()
		return
	move_to_position(companion.follow_target.global_position + companion.follow_offset, companion.preferred_distance)

func move_towards(target_position: Vector2, _delta: float) -> void:
	move_to_position(target_position, companion.preferred_distance)

func move_away_from(target_position: Vector2, _delta: float) -> void:
	var direction: Vector2 = (companion.global_position - target_position).normalized()
	move_to_position(companion.global_position + direction * companion.flee_distance, 8.0)

func move_to_position(target_position: Vector2, stop_distance: float = 18.0) -> void:
	if not is_valid_living_target(companion):
		_stop_companion()
		return
	var to_target: Vector2 = target_position - companion.global_position
	if to_target.length() <= stop_distance:
		companion.velocity = Vector2.ZERO
		_reset_stuck_tracking(target_position, to_target.length())
	else:
		_update_stuck_tracking(target_position, to_target.length())
		if stuck_timer >= stuck_timeout:
			debug_state = "Fallback: stuck while moving to target"
			_log_edge_event("stuck_fallback", {"npc": _npc_id(), "target": str(target_position)})
			_reset_stuck_tracking(target_position, to_target.length())
			if is_dorothy_available():
				var to_dorothy: Vector2 = companion.follow_target.global_position - companion.global_position
				companion.velocity = to_dorothy.normalized() * companion.move_speed * 0.75 if to_dorothy.length() > 1.0 else Vector2.ZERO
			else:
				companion.velocity = Vector2.ZERO
			companion.move_and_slide()
			return
		companion.velocity = to_target.normalized() * companion.move_speed
	companion.move_and_slide()

func get_nearest_enemy(max_distance: float = INF) -> Node2D:
	var nearest: Node2D
	var nearest_distance: float = INF
	for enemy in companion.get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D or not is_valid_living_target(enemy):
			continue
		var distance: float = companion.global_position.distance_to(enemy.global_position)
		if distance <= max_distance and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func get_living_enemies() -> Array[Node2D]:
	var living: Array[Node2D] = []
	for enemy in companion.get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and is_valid_living_target(enemy):
			living.append(enemy)
	return living

func get_nearest_enemy_to_self(max_distance: float = INF) -> Node2D:
	return get_nearest_enemy(max_distance)

func get_nearest_enemy_to_dorothy(max_distance: float = INF) -> Node2D:
	var target_dorothy := get_dorothy()
	if target_dorothy == null:
		return get_nearest_enemy(max_distance)
	var nearest: Node2D
	var nearest_distance: float = INF
	for enemy in get_living_enemies():
		var distance: float = target_dorothy.global_position.distance_to(enemy.global_position)
		if distance <= max_distance and distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	return nearest

func is_combat_active() -> bool:
	return get_nearest_enemy(companion.enemy_detection_radius) != null

func attack_enemy(enemy: Node2D) -> bool:
	if not is_valid_living_target(enemy):
		_log_edge_event("target_invalidated", {"npc": _npc_id(), "reason": "attack_target_invalid"})
		follow_dorothy()
		return false
	if companion.global_position.distance_to(enemy.global_position) > companion.attack_range:
		move_to_position(enemy.global_position, companion.attack_range * 0.8)
		return false
	companion.velocity = Vector2.ZERO
	companion.move_and_slide()
	return companion._try_attack(enemy)

func flee_from_enemy(enemy: Node2D) -> void:
	if not is_valid_living_target(enemy):
		_log_edge_event("target_invalidated", {"npc": _npc_id(), "reason": "flee_target_invalid"})
		follow_dorothy()
		return
	var direction: Vector2 = (companion.global_position - enemy.global_position).normalized()
	move_to_position(companion.global_position + direction * companion.flee_distance, 8.0)

func get_dorothy() -> Node2D:
	return companion.get_tree().get_first_node_in_group("player") as Node2D

func get_companion_by_id(character_id: String) -> CompanionBase:
	for node in companion.get_tree().get_nodes_in_group("companion"):
		if node is CompanionBase and node.character_id == character_id:
			return node
	return null

func get_combat_stats(node: Node) -> CombatStats:
	if node == null:
		return null
	return node.get_node_or_null("CombatStats") as CombatStats

func is_injured(node: Node, threshold: float) -> bool:
	var stats := get_combat_stats(node)
	return is_valid_living_target(node) and stats != null and stats.get_health_percent() < threshold

func heal_ally(ally: Node2D, amount: int = 14, heal_range: float = 52.0) -> bool:
	if not is_valid_living_ally(ally):
		_log_edge_event("target_invalidated", {"npc": _npc_id(), "reason": "heal_target_invalid"})
		follow_dorothy()
		return false
	if companion.global_position.distance_to(ally.global_position) > heal_range:
		move_to_position(ally.global_position, heal_range * 0.8)
		return false
	if support_action_timer > 0.0:
		follow_dorothy()
		return false
	companion.velocity = Vector2.ZERO
	companion.move_and_slide()
	var stats := get_combat_stats(ally)
	if stats:
		var healed: int = stats.heal(amount)
		if healed > 0:
			support_action_timer = support_action_cooldown
			companion._log_combat_event("healing_done", {"source": companion.character_id, "target": ally.name, "amount": healed})
			return true
	return false

func reset_damage(node: Node) -> void:
	var stats := get_combat_stats(node)
	if stats:
		stats.reset_damage_to_base()

func set_damage(node: Node, value: int) -> void:
	var stats := get_combat_stats(node)
	if stats:
		stats.set_damage(value)

func apply_scarecrow_modifiers(mode: String) -> bool:
	if not is_valid_living_target(companion) or not is_dorothy_available():
		_log_edge_event("target_invalidated", {"npc": _npc_id(), "reason": "scarecrow_context_invalid"})
		return false
	if companion.has_method("can_apply_scarecrow_effects") and not companion.can_apply_scarecrow_effects():
		return false
	var dorothy := get_dorothy()
	var lion := get_companion_by_id("lion")
	var nearby_enemies: Array[Node] = []
	reset_damage(dorothy)
	if is_valid_living_ally(lion):
		reset_damage(lion)
	for enemy in companion.get_tree().get_nodes_in_group("enemy"):
		if not is_valid_living_target(enemy):
			continue
		reset_damage(enemy)
		if enemy is Node2D and companion.global_position.distance_to(enemy.global_position) <= 300.0:
			nearby_enemies.append(enemy)

	if mode == "buff":
		var allies_buffed: Array[String] = ["dorothy"]
		set_damage(dorothy, _base_damage(dorothy) + 5)
		if is_valid_living_ally(lion):
			allies_buffed.append("lion")
			set_damage(lion, _base_damage(lion) + 8)
		for enemy in nearby_enemies:
			set_damage(enemy, maxi(_base_damage(enemy) - 5, 1))
		companion._log_combat_event("scarecrow_modifiers_applied", {
			"source": companion.character_id,
			"algorithm": get_algorithm_name(),
			"intelligence": get_stat_value(),
			"allies_buffed": allies_buffed,
			"enemies_weakened": nearby_enemies.size(),
			"allies_harmed": [],
			"enemies_strengthened": 0,
			"decision_time_usec": last_decision_time_usec,
		})
		return true
	elif mode == "bad_strategy":
		var allies_harmed: Array[String] = ["dorothy"]
		set_damage(dorothy, maxi(_base_damage(dorothy) - 3, 1))
		if is_valid_living_ally(lion):
			allies_harmed.append("lion")
			set_damage(lion, maxi(_base_damage(lion) - 6, 1))
		for enemy in nearby_enemies:
			set_damage(enemy, _base_damage(enemy) + 5)
		companion._log_combat_event("scarecrow_modifiers_applied", {
			"source": companion.character_id,
			"algorithm": get_algorithm_name(),
			"intelligence": get_stat_value(),
			"allies_buffed": [],
			"enemies_weakened": 0,
			"allies_harmed": allies_harmed,
			"enemies_strengthened": nearby_enemies.size(),
			"decision_time_usec": last_decision_time_usec,
		})
		return true
	return false

func _base_damage(node: Node) -> int:
	var stats := get_combat_stats(node)
	return stats.base_damage if stats else 1

func is_valid_living_target(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target is Node:
		return false
	if target is CanvasItem and not target.visible:
		return false
	if target.has_method("is_alive"):
		return bool(target.is_alive())
	var stats := get_combat_stats(target)
	return stats != null and stats.is_alive and stats.current_health > 0

func is_valid_living_ally(target) -> bool:
	return is_valid_living_target(target) and target.is_in_group("ally")

func is_dorothy_available() -> bool:
	if companion == null:
		return false
	if companion.follow_target == null or not is_instance_valid(companion.follow_target):
		companion.follow_target = companion.get_tree().get_first_node_in_group("player") as Node2D
	dorothy = companion.follow_target
	return is_valid_living_target(dorothy)

func _stop_companion() -> void:
	if companion and is_instance_valid(companion):
		companion.velocity = Vector2.ZERO
		companion.move_and_slide()

func _reset_stuck_tracking(target_position: Vector2, distance: float) -> void:
	last_move_target = target_position
	last_distance_to_target = distance
	stuck_timer = 0.0

func _update_stuck_tracking(target_position: Vector2, distance: float) -> void:
	if last_move_target == Vector2(INF, INF) or last_move_target.distance_to(target_position) > 8.0:
		_reset_stuck_tracking(target_position, distance)
		return
	if distance < last_distance_to_target - stuck_min_progress:
		_reset_stuck_tracking(target_position, distance)
		return
	stuck_timer += last_ai_delta
	last_distance_to_target = distance

func _npc_id() -> String:
	return str(companion.character_id) if companion else "unknown"

func _log_edge_event(event_name: String, payload: Dictionary = {}) -> void:
	if companion == null or not is_instance_valid(companion):
		return
	var logger := companion.get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_edge_event"):
		logger.log_edge_event(event_name, payload)

func _log_edge_event_once(event_name: String, payload: Dictionary = {}) -> void:
	var key: String = "%s:%s" % [event_name, str(payload.get("reason", ""))]
	if edge_events_logged.has(key):
		return
	edge_events_logged[key] = true
	_log_edge_event(event_name, payload)
