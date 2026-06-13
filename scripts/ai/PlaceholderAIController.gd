extends "res://scripts/ai/AIControllerBase.gd"
class_name PlaceholderAIController

var companion
var stats_manager

func setup(p_companion, p_stats_manager, _combat_stats = null) -> void:
	companion = p_companion
	stats_manager = p_stats_manager

func update_ai(_delta: float) -> void:
	if companion == null or companion.follow_target == null:
		return

	var target_position: Vector2 = companion.follow_target.global_position + companion.follow_offset
	var to_target: Vector2 = target_position - companion.global_position
	if to_target.length() <= companion.follow_stop_distance:
		companion.velocity = Vector2.ZERO
	else:
		companion.velocity = to_target.normalized() * companion.move_speed
	companion.move_and_slide()

func get_debug_state() -> String:
	return "Following Dorothy"

func get_algorithm_name() -> String:
	return "Placeholder"
