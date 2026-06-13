extends RefCounted
class_name GOAPAction

var name: String
var cost: int
var preconditions: Dictionary
var effects: Dictionary

func _init(p_name: String = "", p_cost: int = 1, p_preconditions: Dictionary = {}, p_effects: Dictionary = {}) -> void:
	name = p_name
	cost = p_cost
	preconditions = p_preconditions
	effects = p_effects

func can_run(world_state: Dictionary) -> bool:
	for key in preconditions.keys():
		if world_state.get(key) != preconditions[key]:
			return false
	return true

func execute(_controller) -> void:
	pass
