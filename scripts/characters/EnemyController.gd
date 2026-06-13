extends CharacterBody2D
class_name EnemyController

@export var speed: float = 55.0
@export var detection_radius: float = 260.0
@export var radius: float = 15.0
@export var color: Color = Color(0.85, 0.25, 0.25, 1.0)
@export var should_chase: bool = true
@export var attack_range: float = 34.0
@export var attack_cooldown: float = 1.0

var target: Node2D
var debug_state: String = "Idle"
var attack_timer: float = 0.0
var damage_flash_timer: float = 0.0

@onready var combat_stats: CombatStats = $CombatStats
@onready var health_bar: HealthBar2D = $HealthBar

func _ready() -> void:
	add_to_group("enemy")
	combat_stats.setup(40, 10)
	health_bar.setup(combat_stats)
	combat_stats.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	attack_timer = maxf(attack_timer - delta, 0.0)
	damage_flash_timer = maxf(damage_flash_timer - delta, 0.0)
	if not combat_stats.is_alive:
		debug_state = "Dead"
		return
	target = _get_best_target()

	if should_chase and target:
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() <= attack_range:
			debug_state = "Attacking"
			velocity = Vector2.ZERO
			_try_attack(target)
		elif to_target.length() <= detection_radius:
			debug_state = "Chasing target"
			velocity = to_target.normalized() * speed
		else:
			debug_state = "Idle"
			velocity = Vector2.ZERO
	else:
		debug_state = "Idle"
		velocity = Vector2.ZERO
	move_and_slide()
	queue_redraw()

func get_debug_state() -> String:
	return debug_state

func is_alive() -> bool:
	return combat_stats != null and combat_stats.is_alive and combat_stats.current_health > 0

func _draw() -> void:
	var draw_color: Color = Color.WHITE if damage_flash_timer > 0.0 else color
	draw_circle(Vector2.ZERO, radius, draw_color)

func take_damage(amount: int) -> int:
	if not combat_stats.is_alive:
		return 0
	var received: int = combat_stats.take_damage(amount)
	damage_flash_timer = 0.12
	print("[Combat] %s recebeu %s de dano." % [name, received])
	queue_redraw()
	return received

func _get_best_target() -> Node2D:
	var nearest: Node2D
	var nearest_distance: float = INF
	for node in get_tree().get_nodes_in_group("ally"):
		if not node is Node2D:
			continue
		if node is CanvasItem and not node.visible:
			continue
		var stats := node.get_node_or_null("CombatStats") as CombatStats
		if stats == null or not stats.is_alive:
			continue
		var distance: float = global_position.distance_to(node.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = node
	return nearest

func _try_attack(attack_target: Node2D) -> void:
	if attack_timer > 0.0 or not is_alive():
		return
	var target_stats := attack_target.get_node_or_null("CombatStats") as CombatStats
	if target_stats == null or not target_stats.is_alive:
		return
	attack_timer = attack_cooldown
	var dealt: int = target_stats.take_damage(combat_stats.current_damage)
	_log_combat_event("enemy_damage_dealt", {
		"source": "enemy",
		"target": attack_target.name,
		"amount": dealt,
	})
	print("[Combat] Enemy dealt %s damage." % dealt)

func _on_died() -> void:
	debug_state = "Dead"
	remove_from_group("enemy")
	visible = false
	set_physics_process(false)
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	_log_combat_event("enemy_died", {"source": "enemy"})
	print("[Combat] Enemy died.")

func _log_combat_event(event_name: String, payload: Dictionary) -> void:
	var logger := get_tree().get_first_node_in_group("metrics_logger")
	if logger and logger.has_method("log_combat_event"):
		logger.log_combat_event(event_name, payload)
