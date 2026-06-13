extends "res://scripts/ai/fsm/FSMControllerBase.gd"
class_name ScarecrowFSMController

const EXIT_RADIUS_MULTIPLIER := 1.45
const MIN_REACTIVE_STATE_TIME := 0.8
const FSM_EFFECT_COOLDOWN := 2.0

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	update_state_time(delta)
	companion.buff_timer = maxf(companion.buff_timer - delta, 0.0)
	var intelligence := get_stat_value()
	var enemy := get_nearest_enemy(_get_detection_radius_for_state())
	var can_leave_reactive_state: bool = state_time >= MIN_REACTIVE_STATE_TIME

	if enemy == null and can_leave_reactive_state:
		transition_to("FOLLOW_DOROTHY")
	elif intelligence <= 30:
		transition_to("BAD_STRATEGY")
	elif intelligence >= 70:
		transition_to("BOOST_STRATEGY")
	elif intelligence > 30 and intelligence < 70:
		transition_to("OBSERVE")
	elif can_leave_reactive_state:
		transition_to("FOLLOW_DOROTHY")

	_measure_end(start)
	match state:
		"BOOST_STRATEGY":
			_apply_fsm_scarecrow_effect("buff")
			follow_dorothy()
		"BAD_STRATEGY":
			_apply_fsm_scarecrow_effect("bad_strategy")
			follow_dorothy()
		_:
			_apply_fsm_scarecrow_effect("base")
			follow_dorothy()

func get_debug_state() -> String:
	return state

func _get_detection_radius_for_state() -> float:
	if state == "BOOST_STRATEGY" or state == "BAD_STRATEGY" or state == "OBSERVE":
		return companion.enemy_detection_radius * EXIT_RADIUS_MULTIPLIER
	return companion.enemy_detection_radius

func _apply_fsm_scarecrow_effect(mode: String) -> void:
	var original_interval: float = companion.buff_interval
	companion.buff_interval = FSM_EFFECT_COOLDOWN
	apply_scarecrow_modifiers(mode)
	companion.buff_interval = original_interval
