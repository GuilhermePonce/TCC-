extends "res://scripts/ai/fsm/FSMControllerBase.gd"
class_name TinManFSMController

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	var empathy := get_stat_value()
	var dorothy := get_dorothy()
	var lion := get_companion_by_id("lion")

	if empathy <= 30 and is_combat_active():
		transition_to("IGNORE_COMBAT")
	elif empathy >= 70 and is_injured(dorothy, 0.70):
		transition_to("HEAL_DOROTHY")
	elif empathy >= 70 and is_injured(lion, 0.70):
		transition_to("HEAL_LION")
	elif empathy > 30 and empathy < 70 and is_injured(dorothy, 0.35):
		transition_to("HEAL_DOROTHY")
	else:
		transition_to("FOLLOW_DOROTHY")

	match state:
		"HEAL_DOROTHY":
			if heal_ally(dorothy):
				follow_dorothy()
		"HEAL_LION":
			if heal_ally(lion):
				follow_dorothy()
		"IGNORE_COMBAT":
			follow_dorothy()
		_:
			follow_dorothy()
	_measure_end(start)
