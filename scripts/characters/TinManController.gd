extends CompanionBase

@export var heal_amount: int = 14
@export var heal_range: float = 52.0
@export var heal_cooldown: float = 2.0
@export var ally_detection_radius: float = 260.0

var heal_timer: float = 0.0

func _ready() -> void:
	character_id = "tin_man"
	display_name = "Homem de Lata"
	main_stat_name = "empathy"
	add_to_group("companion")
	color = Color(0.68, 0.71, 0.73, 1.0)

func update_behavior(delta: float) -> void:
	heal_timer = maxf(heal_timer - delta, 0.0)
	var empathy: int = get_main_stat_value()
	var ally_to_heal := _get_priority_ally_to_heal(empathy)

	if empathy >= 70:
		if ally_to_heal:
			debug_state = "Healing ally"
			_move_and_heal(ally_to_heal)
			return
	elif empathy <= 30:
		debug_state = "Ignoring combat"
		_move_toward_position(follow_target.global_position + follow_offset, preferred_distance)
		return
	else:
		if ally_to_heal:
			debug_state = "Following and waiting"
			_move_and_heal(ally_to_heal)
			return
		debug_state = "Following and waiting"

	_move_toward_position(follow_target.global_position + follow_offset, preferred_distance)

func _get_priority_ally_to_heal(empathy: int) -> Node2D:
	var low_health_threshold: float = 0.70 if empathy >= 70 else 0.35
	var dorothy := get_tree().get_first_node_in_group("player") as Node2D
	if _can_heal_candidate(dorothy, low_health_threshold):
		return dorothy
	var lion := _get_companion_by_id("lion")
	if _can_heal_candidate(lion, low_health_threshold):
		return lion
	return null

func _can_heal_candidate(candidate: Node2D, threshold: float) -> bool:
	if candidate == null:
		return false
	var stats := candidate.get_node_or_null("CombatStats") as CombatStats
	if stats == null or not stats.is_alive:
		return false
	return stats.get_health_percent() < threshold and global_position.distance_to(candidate.global_position) <= ally_detection_radius

func _move_and_heal(ally: Node2D) -> void:
	if global_position.distance_to(ally.global_position) > heal_range:
		_move_toward_position(ally.global_position, heal_range * 0.8)
		return
	velocity = Vector2.ZERO
	move_and_slide()
	if heal_timer > 0.0:
		return
	var ally_stats := ally.get_node_or_null("CombatStats") as CombatStats
	if ally_stats == null:
		return
	var healed: int = ally_stats.heal(heal_amount)
	heal_timer = heal_cooldown
	if healed > 0:
		_log_combat_event("healing_done", {
			"source": character_id,
			"target": ally.name,
			"amount": healed,
		})
		print("[Combat] Homem de Lata healed %s HP on %s." % [healed, ally.name])

func _get_companion_by_id(target_id: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("companion"):
		if node is CompanionBase and node.character_id == target_id:
			return node
	return null
