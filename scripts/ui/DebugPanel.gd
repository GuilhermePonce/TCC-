extends PanelContainer

signal skip_to_tests_requested
signal stat_delta_requested(character_id: String, stat_name: String, delta: int)
signal export_logs_requested

var stats_manager: CharacterStatsManager
var scenario_data: Dictionary = {}
var enemy_count_provider: Callable
var combat_context_provider: Callable
var algorithm_mode: String = "GOAP"

@onready var content_label: Label = %ContentLabel
@onready var controls_container: VBoxContainer = %ControlsContainer

func setup(p_stats_manager: CharacterStatsManager) -> void:
	stats_manager = p_stats_manager
	stats_manager.stats_changed.connect(refresh)
	_build_debug_controls()
	refresh()

func set_enemy_count_provider(provider: Callable) -> void:
	enemy_count_provider = provider
	refresh()

func set_combat_context_provider(provider: Callable) -> void:
	combat_context_provider = provider
	refresh()

func set_algorithm_mode(mode: String) -> void:
	algorithm_mode = mode
	refresh()

func set_scenario(p_scenario_data: Dictionary) -> void:
	scenario_data = p_scenario_data
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if stats_manager == null:
		return

	var data: Dictionary = stats_manager.get_all_data()
	var stats: Dictionary = data["stats"]
	var states: Dictionary = data["states"]
	var active_enemy_count: int = enemy_count_provider.call() if enemy_count_provider.is_valid() else 0
	var combat: Dictionary = combat_context_provider.call() if combat_context_provider.is_valid() else {}
	var dorothy: Dictionary = combat.get("dorothy", {})
	var lion: Dictionary = combat.get("lion", {})
	var tin_man: Dictionary = combat.get("tin_man", {})
	var scarecrow: Dictionary = combat.get("scarecrow", {})

	content_label.text = "\n".join([
		"AI Mode: %s" % algorithm_mode,
		"Cenário %s: %s" % [scenario_data.get("id", "-"), scenario_data.get("name", "")],
		"Tipo: %s" % scenario_data.get("type", ""),
		"Dorothy | HP %s/%s | dano %s | ataque %s" % [dorothy.get("hp", 0), dorothy.get("max_hp", 0), dorothy.get("damage", 0), combat.get("dorothy_attack", "")],
		"Leão | coragem %s | HP %s/%s | dano %s | %s" % [stats["lion"]["courage"], lion.get("hp", 0), lion.get("max_hp", 0), lion.get("damage", 0), states["lion"]],
		"Lata | empatia %s | HP %s/%s | dano %s | %s" % [stats["tin_man"]["empathy"], tin_man.get("hp", 0), tin_man.get("max_hp", 0), tin_man.get("damage", 0), states["tin_man"]],
		"Espantalho | inteligência %s | HP %s/%s | dano %s | %s" % [stats["scarecrow"]["intelligence"], scarecrow.get("hp", 0), scarecrow.get("max_hp", 0), scarecrow.get("damage", 0), states["scarecrow"]],
		"Inimigos vivos: %s | dano médio %s" % [active_enemy_count, combat.get("enemy_avg_damage", 0)],
		"Debug: F FSM | B BT | G GOAP | 9 testes | SPACE atacar",
	])

func _build_debug_controls() -> void:
	if controls_container == null:
		return

	for child in controls_container.get_children():
		child.queue_free()

	var skip_button: Button = Button.new()
	skip_button.text = "Ir para cenários de teste"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.custom_minimum_size = Vector2(0, 26)
	skip_button.pressed.connect(func() -> void:
		skip_to_tests_requested.emit()
	)
	controls_container.add_child(skip_button)

	var export_button: Button = Button.new()
	export_button.text = "Export Logs"
	export_button.focus_mode = Control.FOCUS_NONE
	export_button.custom_minimum_size = Vector2(0, 26)
	export_button.pressed.connect(func() -> void:
		export_logs_requested.emit()
	)
	controls_container.add_child(export_button)

	_add_stat_controls("Leão coragem", "lion", "courage")
	_add_stat_controls("Homem de Lata empatia", "tin_man", "empathy")
	_add_stat_controls("Espantalho inteligência", "scarecrow", "intelligence")

func _add_stat_controls(label_text: String, character_id: String, stat_name: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)

	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var minus_button: Button = Button.new()
	minus_button.text = "-10"
	minus_button.focus_mode = Control.FOCUS_NONE
	minus_button.custom_minimum_size = Vector2(46, 24)
	minus_button.pressed.connect(func() -> void:
		stat_delta_requested.emit(character_id, stat_name, -10)
	)
	row.add_child(minus_button)

	var plus_button: Button = Button.new()
	plus_button.text = "+10"
	plus_button.focus_mode = Control.FOCUS_NONE
	plus_button.custom_minimum_size = Vector2(46, 24)
	plus_button.pressed.connect(func() -> void:
		stat_delta_requested.emit(character_id, stat_name, 10)
	)
	row.add_child(plus_button)

	controls_container.add_child(row)
