extends Node2D
class_name HealthBar2D

@export var width: float = 36.0
@export var height: float = 5.0
@export var y_offset: float = -28.0
@export var fill_color: Color = Color(0.15, 0.95, 0.25, 1.0)
@export var background_color: Color = Color(0.08, 0.08, 0.08, 0.9)

var combat_stats: CombatStats

func setup(stats: CombatStats) -> void:
	combat_stats = stats
	if combat_stats:
		combat_stats.health_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if combat_stats == null:
		return
	var percent: float = combat_stats.get_health_percent()
	var origin := Vector2(-width * 0.5, y_offset)
	draw_rect(Rect2(origin, Vector2(width, height)), background_color)
	draw_rect(Rect2(origin, Vector2(width * percent, height)), fill_color)
	if not combat_stats.is_alive:
		visible = false
