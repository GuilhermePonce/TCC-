extends Node
class_name CharacterStatsManager

signal stats_changed

const MIN_STAT: int = 0
const MAX_STAT: int = 100

var stats: Dictionary = {
	"lion": {"courage": 65},
	"tin_man": {"empathy": 65},
	"scarecrow": {"intelligence": 65},
}

var states: Dictionary = {
	"lion": "Following Dorothy",
	"tin_man": "Following Dorothy",
	"scarecrow": "Following Dorothy",
}

func get_stat(character_id: String, stat_name: String) -> int:
	if not stats.has(character_id):
		return 0
	return int(stats[character_id].get(stat_name, 0))

func set_stat(character_id: String, stat_name: String, value: int) -> void:
	if not stats.has(character_id):
		stats[character_id] = {}
	stats[character_id][stat_name] = clampi(value, MIN_STAT, MAX_STAT)
	stats_changed.emit()

func add_stat(character_id: String, stat_name: String, delta: int) -> void:
	set_stat(character_id, stat_name, get_stat(character_id, stat_name) + delta)

func set_state(character_id: String, state_text: String) -> void:
	if str(states.get(character_id, "")) == state_text:
		return
	states[character_id] = state_text
	stats_changed.emit()

func get_all_data() -> Dictionary:
	return {
		"stats": stats.duplicate(true),
		"states": states.duplicate(true),
	}
