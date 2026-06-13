extends CharacterBody2D
class_name CompanionBase

@export var character_id: String = ""
@export var display_name: String = ""
@export var main_stat_name: String = ""
@export var move_speed: float = 145.0
@export var follow_offset: Vector2 = Vector2.ZERO
@export var preferred_distance: float = 18.0
@export var follow_stop_distance: float = 18.0
@export var radius: float = 16.0
@export var color: Color = Color.WHITE
@export var attack_range: float = 48.0
@export var attack_cooldown: float = 0.8
@export var flee_distance: float = 170.0
@export var enemy_detection_radius: float = 280.0

var follow_target: Node2D
var stats_manager: CharacterStatsManager
var ai_controller
var debug_state: String = "Following Dorothy"
var attack_timer: float = 0.0
var ai_metrics_timer: float = 0.0

@onready var combat_stats: CombatStats = $CombatStats
@onready var health_bar: HealthBar2D = $HealthBar

func setup(p_stats_manager: CharacterStatsManager, p_follow_target: Node2D) -> void:
	stats_manager = p_stats_manager
	follow_target = p_follow_target
	if follow_target == null:
		follow_target = get_tree().get_first_node_in_group("player") as Node2D
	add_to_group("ally")
	_setup_combat()
	health_bar.setup(combat_stats)
	combat_stats.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	if combat_stats and not combat_stats.is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if ai_controller:
		ai_controller.update_ai(delta)
		_log_ai_metrics(delta)
	else:
		update_behavior(delta)
	_update_debug_state()

func set_ai_controller(controller) -> void:
	ai_controller = controller
	if ai_controller and ai_controller.has_method("setup"):
		ai_controller.setup(self, stats_manager, combat_stats)

func update_behavior(_delta: float) -> void:
	if follow_target == null:
		follow_target = get_tree().get_first_node_in_group("player") as Node2D
	if follow_target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var target_position: Vector2 = _get_behavior_target_position()
	_move_toward_position(target_position, preferred_distance)

func get_debug_state() -> String:
	if combat_stats and not combat_stats.is_alive:
		return "Dead"
	if ai_controller:
		return ai_controller.get_debug_state()
	return debug_state

func is_alive() -> bool:
	return combat_stats != null and combat_stats.is_alive and combat_stats.current_health > 0

func get_main_stat_value() -> int:
	if stats_manager == null or main_stat_name.is_empty():
		return 0
	return stats_manager.get_stat(character_id, main_stat_name)

func _get_behavior_target_position() -> Vector2:
	var nearest_enemy: Node2D = _get_nearest_enemy(enemy_detection_radius)
	var stat_value: int = get_main_stat_value()

	match character_id:
		"lion":
			if nearest_enemy and stat_value >= 70:
				debug_state = "Attacking enemy bravely"
				_try_attack(nearest_enemy)
				return nearest_enemy.global_position
			if nearest_enemy and stat_value <= 30:
				debug_state = "Fleeing from enemy"
				return global_position + (global_position - nearest_enemy.global_position).normalized() * flee_distance
			if nearest_enemy and follow_target.global_position.distance_to(nearest_enemy.global_position) <= 80.0:
				debug_state = "Following Dorothy cautiously"
				_try_attack(nearest_enemy)
				return follow_target.global_position + follow_offset
			debug_state = "Following Dorothy cautiously"
			return follow_target.global_position + follow_offset
		"tin_man":
			if nearest_enemy and stat_value >= 70:
				debug_state = "Helping ally"
				return _get_ally_closest_to_enemy(nearest_enemy).global_position
			if stat_value <= 30:
				debug_state = "Following mechanically"
				return follow_target.global_position + follow_offset
		"scarecrow":
			if nearest_enemy and stat_value >= 70:
				debug_state = "Avoiding threat strategically"
				return global_position + (global_position - nearest_enemy.global_position).normalized() * 130.0
			if stat_value <= 30:
				debug_state = "Following without strategy"
				return follow_target.global_position

	debug_state = "Following Dorothy"
	return follow_target.global_position + follow_offset

func _move_toward_position(target_position: Vector2, stop_distance: float) -> void:
	var to_target: Vector2 = target_position - global_position
	if to_target.length() <= stop_distance:
		velocity = Vector2.ZERO
	else:
		velocity = to_target.normalized() * move_speed
	move_and_slide()

func _get_nearest_enemy(max_distance: float = INF) -> Node2D:
	var nearest_enemy: Node2D
	var nearest_distance: float = INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var enemy_stats := enemy.get_node_or_null("CombatStats") as CombatStats
			if enemy_stats == null or not enemy_stats.is_alive:
				continue
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance <= max_distance and distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	return nearest_enemy

func _get_ally_closest_to_enemy(enemy: Node2D) -> Node2D:
	var closest_ally: Node2D = follow_target
	var closest_distance: float = follow_target.global_position.distance_to(enemy.global_position)
	for node in get_tree().get_nodes_in_group("companion"):
		if node == self or not (node is Node2D) or not node.visible:
			continue
		var distance: float = node.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_ally = node
	return closest_ally

func _update_debug_state() -> void:
	if stats_manager:
		stats_manager.set_state(character_id, get_debug_state())

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)

func _setup_combat() -> void:
	match character_id:
		"lion":
			combat_stats.setup(120, 18)
		"tin_man":
			combat_stats.setup(110, 8, 2)
		"scarecrow":
			combat_stats.setup(90, 6)
		_:
			combat_stats.setup(100, 5)

func _try_attack(enemy: Node2D) -> bool:
	if attack_timer > 0.0 or enemy == null:
		return false
	if not is_alive():
		return false
	if global_position.distance_to(enemy.global_position) > attack_range:
		return false
	var enemy_stats := enemy.get_node_or_null("CombatStats") as CombatStats
	if enemy_stats == null or not enemy_stats.is_alive:
		return false
	attack_timer = attack_cooldown
	var dealt: int = enemy_stats.take_damage(combat_stats.current_damage)
	_log_combat_event("damage_dealt", {
		"source": character_id,
		"target": "enemy",
		"amount": dealt,
	})
	print("[Combat] %s dealt %s damage to enemy." % [display_name, dealt])
	return dealt > 0

func _on_died() -> void:
	debug_state = "Dead"
	visible = false
	set_physics_process(false)
	remove_from_group("ally")
	remove_from_group("companion")
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if stats_manager:
		stats_manager.set_state(character_id, "Dead")
	_log_edge_event("npc_dead", {"npc": character_id})
	print("[Combat] %s died." % display_name)

func _log_combat_event(event_name: String, payload: Dictionary) -> void:
	var logger := get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_combat_event"):
		logger.log_combat_event(event_name, payload)

func _log_edge_event(event_name: String, payload: Dictionary) -> void:
	var logger := get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_edge_event"):
		logger.log_edge_event(event_name, payload)

func _log_ai_metrics(delta: float) -> void:
	ai_metrics_timer = maxf(ai_metrics_timer - delta, 0.0)
	if ai_metrics_timer > 0.0 or ai_controller == null:
		return
	ai_metrics_timer = 1.0
	var logger := get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_ai_update") and ai_controller.has_method("get_metrics_data"):
		var data: Dictionary = ai_controller.get_metrics_data()
		data["npc_id"] = character_id
		logger.log_ai_update(data)
