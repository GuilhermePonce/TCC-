extends "res://scripts/ai/bt/BTControllerBase.gd"
class_name TinManBTController

func update_ai(delta: float) -> void:
	var start := _measure_start()
	if not begin_ai_update(delta):
		_measure_end(start)
		return
	var empathy := get_stat_value()
	var dorothy := get_dorothy()
	var lion := get_companion_by_id("lion")

	if empathy <= 30 and is_combat_active():
		succeed("IgnoreCombat")
		follow_dorothy()
	elif empathy >= 70 and is_injured(dorothy, 0.70):
		succeed("HealDorothy")
		if heal_ally(dorothy):
			follow_dorothy()
	elif empathy >= 70 and is_injured(lion, 0.70):
		succeed("HealLion")
		if heal_ally(lion):
			follow_dorothy()
	elif empathy > 30 and empathy < 70 and is_injured(dorothy, 0.35):
		succeed("HealDorothy")
		if heal_ally(dorothy):
			follow_dorothy()
	else:
		succeed("FollowDorothy")
		follow_dorothy()
	_measure_end(start)
