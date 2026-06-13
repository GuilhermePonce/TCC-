extends CharacterBody2D

@export var move_speed: float = 220.0
@export var radius: float = 18.0
@export var color: Color = Color(1.0, 0.48, 0.78, 1.0)
@export var attack_range: float = 54.0
@export var attack_cooldown: float = 0.45

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var combat_stats: CombatStats = $CombatStats
@onready var health_bar: HealthBar2D = $HealthBar

var can_attack: bool = true
var attack_timer: float = 0.0
var attack_flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	add_to_group("ally")
	combat_stats.setup(100, 15)
	health_bar.setup(combat_stats)
	combat_stats.died.connect(_on_died)
	_sync_attack_area()

func _physics_process(delta: float) -> void:
	if not is_alive():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_update_attack_cooldown(delta)
	attack_flash_timer = maxf(attack_flash_timer - delta, 0.0)

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * move_speed
	move_and_slide()

	if Input.is_action_just_pressed("attack"):
		try_attack()

	queue_redraw()

func try_attack() -> void:
	if not can_attack or not is_alive():
		return

	var target := get_nearest_enemy_in_attack_area()
	if target == null:
		return
	if not target.has_method("take_damage"):
		return

	var dealt: int = int(target.take_damage(combat_stats.current_damage))
	can_attack = false
	attack_timer = attack_cooldown
	attack_flash_timer = 0.12
	_log_combat_event("damage_dealt", {
		"source": "dorothy",
		"target": target.name,
		"amount": dealt,
	})
	print("[Combat] Dorothy causou %s de dano em %s." % [dealt, target.name])

func get_nearest_enemy_in_attack_area() -> Node2D:
	var nearest: Node2D
	var nearest_distance: float = INF
	var candidates: Array[Node] = []
	candidates.append_array(attack_area.get_overlapping_bodies())
	candidates.append_array(attack_area.get_overlapping_areas())

	for candidate in candidates:
		var enemy := _get_enemy_node(candidate)
		if enemy == null:
			continue
		if not _is_enemy_alive(enemy):
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest

func get_attack_state_text() -> String:
	if can_attack:
		return "pronto"
	return "%.1fs" % attack_timer

func _get_enemy_node(candidate: Node) -> Node2D:
	if candidate is Node2D and candidate.is_in_group("enemy"):
		return candidate
	var parent := candidate.get_parent()
	if parent is Node2D and parent.is_in_group("enemy"):
		return parent
	return null

func _is_enemy_alive(enemy: Node2D) -> bool:
	var enemy_stats := enemy.get_node_or_null("CombatStats") as CombatStats
	return enemy_stats != null and enemy_stats.is_alive

func is_alive() -> bool:
	return combat_stats != null and combat_stats.is_alive and combat_stats.current_health > 0

func _update_attack_cooldown(delta: float) -> void:
	if can_attack:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	if attack_timer <= 0.0:
		can_attack = true

func _sync_attack_area() -> void:
	if attack_shape and attack_shape.shape is CircleShape2D:
		(attack_shape.shape as CircleShape2D).radius = attack_range

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	if attack_flash_timer > 0.0:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(1.0, 0.95, 0.45, 0.9), 3.0)

func _on_died() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	_log_edge_event("dorothy_down", {"npc": "dorothy", "reason": "player_dead"})
	print("[Combat] Dorothy died.")

func _log_combat_event(event_name: String, payload: Dictionary) -> void:
	var logger := get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_combat_event"):
		logger.log_combat_event(event_name, payload)

func _log_edge_event(event_name: String, payload: Dictionary) -> void:
	var logger := get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_edge_event"):
		logger.log_edge_event(event_name, payload)
