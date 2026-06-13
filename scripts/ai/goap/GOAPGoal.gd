extends RefCounted
class_name GOAPGoal

var name: String
var desired_state: Dictionary
var priority: int

func _init(p_name: String = "", p_desired_state: Dictionary = {}, p_priority: int = 1) -> void:
	name = p_name
	desired_state = p_desired_state
	priority = p_priority
