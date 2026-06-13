extends "res://scripts/ai/fsm/FSMControllerBase.gd"
class_name LionFSMController

const EXIT_RADIUS_MULTIPLIER := 1.45
const MIN_REACTIVE_STATE_TIME := 0.65

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	update_state_time(delta)
	var enemy := get_nearest_enemy_to_dorothy(_get_detection_radius_for_state())
	var courage := get_stat_value()
	var can_leave_reactive_state: bool = state_time >= MIN_REACTIVE_STATE_TIME

	if enemy == null and can_leave_reactive_state:
		transition_to("FOLLOW_DOROTHY")
	elif enemy and courage >= 70:
		transition_to("ATTACK_ENEMY")
	elif enemy and courage <= 30:
		transition_to("FLEE_ENEMY")
	elif can_leave_reactive_state:
		transition_to("FOLLOW_DOROTHY")

	match state:
		"ATTACK_ENEMY":
			if attack_enemy(enemy):
				follow_dorothy()
		"FLEE_ENEMY":
			if enemy:
				flee_from_enemy(enemy)
			else:
				companion.velocity = Vector2.ZERO
				companion.move_and_slide()
		_:
			follow_dorothy()
	_measure_end(start)

func _get_detection_radius_for_state() -> float:
	if state == "ATTACK_ENEMY" or state == "FLEE_ENEMY":
		return companion.enemy_detection_radius * EXIT_RADIUS_MULTIPLIER
	return companion.enemy_detection_radius
