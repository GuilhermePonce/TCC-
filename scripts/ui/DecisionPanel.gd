extends PanelContainer

signal challenge_started

var decision_manager: DecisionManager

@onready var title_label: Label = %TitleLabel
@onready var event_label: Label = %EventLabel
@onready var buttons_container: VBoxContainer = %Buttons

func setup(p_decision_manager: DecisionManager) -> void:
	decision_manager = p_decision_manager

func show_scenario(scenario_data: Dictionary) -> void:
	title_label.text = "%s  [%s]" % [str(scenario_data.get("name", "Cenário")), str(scenario_data.get("type", ""))]
	event_label.text = str(scenario_data.get("book_event", ""))

	for child in buttons_container.get_children():
		child.queue_free()

	var decisions: Array = scenario_data.get("decisions", [])
	if not decisions.is_empty():
		for decision in decisions:
			var decision_data: Dictionary = decision
			var button: Button = Button.new()
			button.text = str(decision_data.get("text", "Decisão"))
			button.custom_minimum_size = Vector2(0, 42)
			button.pressed.connect(func() -> void:
				decision_manager.apply_decision(decision_data)
			)
			buttons_container.add_child(button)
	else:
		var start_button: Button = Button.new()
		start_button.text = "Iniciar desafio"
		start_button.custom_minimum_size = Vector2(0, 42)
		start_button.pressed.connect(func() -> void:
			challenge_started.emit()
		)
		buttons_container.add_child(start_button)

	visible = true

func hide_panel() -> void:
	visible = false
