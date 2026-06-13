extends CompanionBase

@export var buff_radius: float = 300.0
@export var buff_interval: float = 0.7
@export var ally_damage_bonus: int = 5
@export var lion_damage_bonus: int = 8
@export var enemy_damage_reduction: int = 5
@export var panic_enemy_bonus: int = 5
@export var panic_ally_penalty: int = 3
@export var panic_lion_penalty: int = 6

var buff_timer: float = 0.0

func _ready() -> void:
	character_id = "scarecrow"
	display_name = "Espantalho"
	main_stat_name = "intelligence"
	add_to_group("companion")
	color = Color(0.54, 0.35, 0.17, 1.0)

func update_behavior(delta: float) -> void:
	if not is_alive():
		debug_state = "Dead"
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if follow_target == null or not is_instance_valid(follow_target) or not _is_living_node(follow_target):
		debug_state = "No active player target"
		velocity = Vector2.ZERO
		move_and_slide()
		return
	buff_timer = maxf(buff_timer - delta, 0.0)
	if buff_timer <= 0.0:
		_apply_damage_modifiers()
	_move_toward_position(follow_target.global_position + follow_offset, preferred_distance)

func can_apply_scarecrow_effects() -> bool:
	if buff_timer > 0.0:
		return false
	buff_timer = buff_interval
	return true

func _apply_damage_modifiers() -> void:
	var intelligence: int = get_main_stat_value()
	var dorothy := get_tree().get_first_node_in_group("player") as Node2D
	var lion := _get_companion_by_id("lion")
	var nearby_enemies: Array[Node] = _get_nearby_enemies()

	_reset_damage_if_present(dorothy)
	if _is_living_node(lion):
		_reset_damage_if_present(lion)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if _is_living_node(enemy):
			_reset_damage_if_present(enemy as Node2D)

	if intelligence >= 70:
		var allies_buffed: Array[String] = ["dorothy"]
		debug_state = "Boosting allies and weakening enemies"
		_set_damage_if_present(dorothy, _get_base_damage(dorothy) + ally_damage_bonus)
		if _is_living_node(lion):
			allies_buffed.append("lion")
			_set_damage_if_present(lion, _get_base_damage(lion) + lion_damage_bonus)
		for enemy in nearby_enemies:
			_set_damage_if_present(enemy as Node2D, maxi(_get_base_damage(enemy as Node2D) - enemy_damage_reduction, 1))
		_log_combat_event("scarecrow_modifiers_applied", {"source": character_id, "mode": "high_intelligence", "intelligence": intelligence, "allies_buffed": allies_buffed, "enemies_weakened": nearby_enemies.size(), "allies_harmed": [], "enemies_strengthened": 0})
	elif intelligence <= 30:
		var allies_harmed: Array[String] = ["dorothy"]
		debug_state = "Making poor tactical decisions"
		_set_damage_if_present(dorothy, maxi(_get_base_damage(dorothy) - panic_ally_penalty, 1))
		if _is_living_node(lion):
			allies_harmed.append("lion")
			_set_damage_if_present(lion, maxi(_get_base_damage(lion) - panic_lion_penalty, 1))
		for enemy in nearby_enemies:
			_set_damage_if_present(enemy as Node2D, _get_base_damage(enemy as Node2D) + panic_enemy_bonus)
		_log_combat_event("scarecrow_modifiers_applied", {"source": character_id, "mode": "low_intelligence", "intelligence": intelligence, "allies_buffed": [], "enemies_weakened": 0, "allies_harmed": allies_harmed, "enemies_strengthened": nearby_enemies.size()})
	else:
		debug_state = "Observing the situation"
	buff_timer = buff_interval

func _get_nearby_enemies() -> Array[Node]:
	var enemies: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and _is_living_node(enemy) and global_position.distance_to(enemy.global_position) <= buff_radius:
			var stats := _get_combat_stats(enemy as Node2D)
			if stats and stats.is_alive:
				enemies.append(enemy)
	return enemies

func _reset_damage_if_present(node: Node2D) -> void:
	var stats := _get_combat_stats(node)
	if stats:
		stats.reset_damage_to_base()

func _set_damage_if_present(node: Node2D, value: int) -> void:
	var stats := _get_combat_stats(node)
	if stats:
		stats.set_damage(value)

func _get_base_damage(node: Node2D) -> int:
	var stats := _get_combat_stats(node)
	return stats.base_damage if stats else 1

func _get_combat_stats(node: Node2D) -> CombatStats:
	if node == null:
		return null
	return node.get_node_or_null("CombatStats") as CombatStats

func _is_living_node(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node is Node:
		return false
	var stats := node.get_node_or_null("CombatStats") as CombatStats
	return stats != null and stats.is_alive and stats.current_health > 0

func _get_companion_by_id(target_id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("companion"):
		if node is CompanionBase and node.character_id == target_id:
			return node
	return null
