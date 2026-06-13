extends Node
class_name CombatStats

signal health_changed
signal died
signal damage_changed

@export var max_health: int = 100
@export var base_damage: int = 5
@export var defense: int = 0

var current_health: int
var current_damage: int
var is_alive: bool = true

func _ready() -> void:
	current_health = max_health
	current_damage = base_damage

func setup(p_max_health: int, p_base_damage: int, p_defense: int = 0) -> void:
	max_health = p_max_health
	base_damage = p_base_damage
	defense = p_defense
	current_health = max_health
	current_damage = base_damage
	is_alive = true
	health_changed.emit()
	damage_changed.emit()

func take_damage(amount: int) -> int:
	if not is_alive:
		return 0
	var damage_received: int = max(amount - defense, 1)
	current_health = maxi(current_health - damage_received, 0)
	health_changed.emit()
	if current_health <= 0:
		die()
	return damage_received

func heal(amount: int) -> int:
	if not is_alive:
		return 0
	var previous_health: int = current_health
	current_health = mini(current_health + amount, max_health)
	health_changed.emit()
	return current_health - previous_health

func set_damage(value: int) -> void:
	current_damage = maxi(value, 1)
	damage_changed.emit()

func add_damage(delta: int) -> void:
	set_damage(current_damage + delta)

func reset_damage_to_base() -> void:
	set_damage(base_damage)

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	current_health = 0
	health_changed.emit()
	died.emit()

func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)
