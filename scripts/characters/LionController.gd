extends CompanionBase

func _ready() -> void:
	character_id = "lion"
	display_name = "Leão"
	main_stat_name = "courage"
	add_to_group("companion")
	color = Color(0.95, 0.55, 0.16, 1.0)

func setup(p_stats_manager: CharacterStatsManager, p_follow_target: Node2D) -> void:
	super.setup(p_stats_manager, p_follow_target)
	_ignore_dorothy_collision()

func _on_died() -> void:
	super._on_died()

func _ignore_dorothy_collision() -> void:
	var dorothy_body := follow_target as CollisionObject2D
	if dorothy_body:
		add_collision_exception_with(dorothy_body)
		dorothy_body.add_collision_exception_with(self)
