extends Node2D
class_name ScenarioController

signal decision_triggered
signal challenge_triggered
signal exit_reached

const MAP_SIZE := Vector2(920, 620)

var completed: bool = false
var decision_was_triggered: bool = false
var requires_decision: bool = true
var challenge_was_triggered: bool = false
var decision_trigger: Area2D
var exit_area: Area2D
var visual_root: Node2D
var enemy_spawn_positions: Array[Vector2] = []
var current_scenario_id: int = 0
var special_nodes: Dictionary = {}

func _ready() -> void:
	decision_trigger = get_node_or_null("DecisionTrigger") as Area2D
	exit_area = get_node_or_null("ExitArea") as Area2D
	if exit_area == null:
		exit_area = get_node_or_null("Exit") as Area2D

	if decision_trigger:
		decision_trigger.body_entered.connect(_on_decision_trigger_body_entered)
	if exit_area:
		exit_area.body_entered.connect(_on_exit_body_entered)

func configure(scenario_data: Dictionary) -> void:
	completed = false
	decision_was_triggered = false
	challenge_was_triggered = false
	current_scenario_id = int(scenario_data.get("id", 0))
	var decisions: Array = scenario_data.get("decisions", [])
	requires_decision = not decisions.is_empty()

	_build_visuals(scenario_data)
	_set_area_enabled(exit_area, false)
	_set_area_label_visible(exit_area, false)
	_set_area_enabled(decision_trigger, true)
	_set_area_label_text(decision_trigger, "Decisão" if requires_decision else "Desafio")

func get_spawn_position(spawn_id: String) -> Vector2:
	var marker: Node = get_node_or_null("Spawns/%s" % spawn_id)
	if marker is Node2D:
		return marker.global_position
	return global_position

func get_enemy_spawn_positions(_enemy_count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for position in enemy_spawn_positions:
		positions.append(position)
	return positions

func apply_decision_result(decision_data: Dictionary) -> void:
	match current_scenario_id:
		1:
			_hide_special("ScarecrowPost")
		2:
			_show_result_note("Homem de Lata voltou a se mover.")
		3:
			var text: String = str(decision_data.get("text", ""))
			if text.contains("Incentivar"):
				_move_marker("lion", Vector2(500, 300))
			elif text.contains("Criticar"):
				_move_marker("lion", Vector2(300, 365))
		4:
			_highlight_route(Color(0.95, 0.9, 0.25, 0.95))
		5:
			_hide_special("BridgeBlock")
		6:
			_hide_special("SeparatedFence")
		7:
			_hide_special("GateLeft")
			_hide_special("GateRight")
		8:
			_show_result_note("O grupo parte para enfrentar a Bruxa do Oeste.")

func mark_completed() -> void:
	completed = true
	decision_was_triggered = true
	_set_area_enabled(decision_trigger, false)
	_set_area_enabled(exit_area, true)
	_set_area_label_visible(exit_area, true)

func _build_visuals(scenario_data: Dictionary) -> void:
	_ensure_visual_root()
	_clear_visuals()
	enemy_spawn_positions.clear()
	special_nodes.clear()

	var scenario_id: int = int(scenario_data.get("id", 0))
	match scenario_id:
		1:
			_build_scarecrow_field()
		2:
			_build_tin_man_forest()
		3:
			_build_lion_clearing()
		4:
			_build_forest_crossing()
		5:
			_build_kalidah_bridge()
		6:
			_build_danger_field()
		7:
			_build_emerald_gate()
		8:
			_build_wizard_room()
		9:
			_build_wolf_road()
		10:
			_build_crow_field()
		11:
			_build_bee_hives()
		12:
			_build_winkie_field()
		13:
			_build_flying_monkeys()
		14:
			_build_rescue_prison()
		15:
			_build_witch_castle()
		16:
			_build_witch_defeat_room()
		17:
			_build_return_road()
		18:
			_build_glinda_journey()
		19:
			_build_final_cooperation()
		_:
			_build_generic_scene(str(scenario_data.get("type", "")))

func _build_scarecrow_field() -> void:
	_set_ground(Color(0.48, 0.70, 0.36, 1.0))
	_add_rect(Vector2(0, 280), Vector2(920, 70), Color(0.92, 0.77, 0.22, 1.0))
	_add_rect(Vector2(120, 85), Vector2(230, 130), Color(0.44, 0.29, 0.14, 1.0))
	_add_rect(Vector2(590, 395), Vector2(210, 115), Color(0.32, 0.52, 0.22, 1.0))
	for x in [145, 190, 235, 280, 620, 665, 710, 755]:
		_add_line(Vector2(x, 92), Vector2(x, 205), Color(0.22, 0.38, 0.15, 1.0), 3.0)
	_add_line(Vector2(455, 210), Vector2(455, 365), Color(0.42, 0.28, 0.12, 1.0), 10.0, "ScarecrowPost")
	_add_line(Vector2(410, 250), Vector2(500, 250), Color(0.42, 0.28, 0.12, 1.0), 7.0)
	_set_marker_positions({"dorothy": Vector2(90, 315), "scarecrow": Vector2(455, 250), "enemy": Vector2(735, 125)})
	_set_area_position(decision_trigger, Vector2(455, 280))
	_set_area_position(exit_area, Vector2(860, 315))
	enemy_spawn_positions = [Vector2(720, 120), Vector2(790, 150)]

func _build_tin_man_forest() -> void:
	_set_ground(Color(0.19, 0.42, 0.23, 1.0))
	_add_rect(Vector2(0, 350), Vector2(920, 70), Color(0.68, 0.55, 0.28, 1.0))
	_add_rect(Vector2(570, 250), Vector2(120, 100), Color(0.36, 0.24, 0.14, 1.0), true)
	_add_rect(Vector2(595, 220), Vector2(70, 35), Color(0.45, 0.29, 0.16, 1.0))
	for p in [Vector2(160, 120), Vector2(250, 190), Vector2(350, 105), Vector2(470, 175), Vector2(760, 170), Vector2(230, 500), Vector2(420, 485), Vector2(700, 470)]:
		_add_tree(p)
	_add_rect(Vector2(390, 285), Vector2(110, 24), Color(0.30, 0.18, 0.10, 1.0), true)
	_add_circle(Vector2(520, 325), 14.0, Color(0.45, 0.75, 0.95, 1.0))
	_set_marker_positions({"dorothy": Vector2(95, 420), "tin_man": Vector2(610, 340), "enemy": Vector2(440, 120)})
	_set_area_position(decision_trigger, Vector2(520, 325))
	_set_area_position(exit_area, Vector2(850, 385))

func _build_lion_clearing() -> void:
	_set_ground(Color(0.13, 0.32, 0.17, 1.0))
	_add_rect(Vector2(0, 270), Vector2(920, 90), Color(0.50, 0.40, 0.20, 1.0))
	_add_circle(Vector2(450, 315), 130.0, Color(0.30, 0.50, 0.24, 1.0))
	_add_rect(Vector2(620, 210), Vector2(170, 180), Color(0.09, 0.08, 0.09, 0.75))
	for y in [80, 145, 430, 500]:
		for x in [120, 230, 340, 690, 800]:
			_add_tree(Vector2(x, y))
	_set_marker_positions({"dorothy": Vector2(80, 315), "lion": Vector2(420, 315), "enemy": Vector2(710, 305)})
	_set_area_position(decision_trigger, Vector2(450, 315))
	_set_area_position(exit_area, Vector2(850, 315))
	enemy_spawn_positions = [Vector2(720, 270), Vector2(760, 330)]

func _build_forest_crossing() -> void:
	_set_ground(Color(0.18, 0.38, 0.20, 1.0))
	_add_rect(Vector2(430, 500), Vector2(70, 120), Color(0.72, 0.58, 0.28, 1.0))
	_add_line(Vector2(465, 500), Vector2(245, 90), Color(0.72, 0.58, 0.28, 1.0), 44.0)
	_add_line(Vector2(465, 500), Vector2(465, 85), Color(0.65, 0.50, 0.24, 1.0), 38.0)
	_add_line(Vector2(465, 500), Vector2(700, 90), Color(0.80, 0.68, 0.36, 1.0), 34.0)
	for x in range(90, 850, 95):
		_add_tree(Vector2(x, 235))
		_add_tree(Vector2(x + 35, 390))
	_add_rect(Vector2(205, 155), Vector2(75, 40), Color(0.55, 0.32, 0.16, 1.0), true)
	_add_rect(Vector2(430, 300), Vector2(70, 40), Color(0.55, 0.32, 0.16, 1.0), true)
	_add_rect(Vector2(655, 235), Vector2(80, 40), Color(0.22, 0.42, 0.20, 1.0), true)
	_set_marker_positions({"dorothy": Vector2(465, 560), "lion": Vector2(535, 525), "tin_man": Vector2(400, 525), "scarecrow": Vector2(340, 550), "enemy": Vector2(245, 165)})
	_set_area_position(decision_trigger, Vector2(465, 470))
	_set_area_position(exit_area, Vector2(465, 60))
	enemy_spawn_positions = [Vector2(245, 165), Vector2(300, 210)]

func _build_kalidah_bridge() -> void:
	_set_ground(Color(0.15, 0.30, 0.22, 1.0))
	_add_rect(Vector2(0, 0), Vector2(920, 190), Color(0.06, 0.05, 0.07, 1.0))
	_add_rect(Vector2(0, 430), Vector2(920, 190), Color(0.06, 0.05, 0.07, 1.0))
	_add_rect(Vector2(0, 265), Vector2(920, 90), Color(0.62, 0.42, 0.18, 1.0))
	_add_rect(Vector2(520, 250), Vector2(95, 120), Color(0.34, 0.12, 0.12, 0.35), true, "BridgeBlock")
	_set_marker_positions({"dorothy": Vector2(80, 310), "lion": Vector2(155, 270), "tin_man": Vector2(150, 350), "scarecrow": Vector2(105, 380), "enemy": Vector2(555, 310)})
	_set_area_position(decision_trigger, Vector2(365, 310))
	_set_area_position(exit_area, Vector2(850, 310))
	enemy_spawn_positions = [Vector2(540, 285), Vector2(590, 335)]

func _build_danger_field() -> void:
	_set_ground(Color(0.56, 0.68, 0.34, 1.0))
	_add_rect(Vector2(0, 290), Vector2(920, 60), Color(0.72, 0.59, 0.28, 1.0))
	for p in [Vector2(280, 250), Vector2(405, 365), Vector2(560, 225), Vector2(650, 400)]:
		_add_circle(p, 48.0, Color(0.80, 0.10, 0.10, 0.45))
	_add_rect(Vector2(420, 125), Vector2(170, 90), Color(0.35, 0.23, 0.14, 1.0), true, "SeparatedFence")
	_set_marker_positions({"dorothy": Vector2(90, 320), "lion": Vector2(140, 270), "tin_man": Vector2(470, 165), "scarecrow": Vector2(125, 375), "enemy": Vector2(610, 300)})
	_set_area_position(decision_trigger, Vector2(410, 320))
	_set_area_position(exit_area, Vector2(850, 320))
	enemy_spawn_positions = [Vector2(610, 260), Vector2(690, 360)]

func _build_emerald_gate() -> void:
	_set_ground(Color(0.16, 0.44, 0.34, 1.0))
	_add_rect(Vector2(410, 0), Vector2(100, 620), Color(0.92, 0.77, 0.22, 1.0))
	_add_rect(Vector2(250, 165), Vector2(420, 270), Color(0.18, 0.65, 0.38, 1.0))
	_add_rect(Vector2(340, 245), Vector2(105, 145), Color(0.06, 0.38, 0.20, 1.0), true, "GateLeft")
	_add_rect(Vector2(475, 245), Vector2(105, 145), Color(0.06, 0.38, 0.20, 1.0), true, "GateRight")
	_add_circle(Vector2(460, 225), 22.0, Color(0.70, 0.90, 1.0, 1.0))
	_set_marker_positions({"dorothy": Vector2(460, 560), "lion": Vector2(525, 535), "tin_man": Vector2(395, 535), "scarecrow": Vector2(335, 560), "enemy": Vector2(760, 120)})
	_set_area_position(decision_trigger, Vector2(460, 415))
	_set_area_position(exit_area, Vector2(460, 85))

func _build_wizard_room() -> void:
	_set_ground(Color(0.08, 0.35, 0.22, 1.0))
	_add_rect(Vector2(170, 70), Vector2(580, 470), Color(0.13, 0.52, 0.32, 1.0))
	_add_circle(Vector2(460, 190), 82.0, Color(0.20, 0.95, 0.42, 0.85))
	_add_circle(Vector2(460, 385), 32.0, Color(0.68, 0.71, 0.73, 1.0))
	_add_circle(Vector2(600, 385), 32.0, Color(0.54, 0.35, 0.17, 1.0))
	_set_marker_positions({"dorothy": Vector2(460, 520), "lion": Vector2(535, 500), "tin_man": Vector2(390, 500), "scarecrow": Vector2(330, 520), "enemy": Vector2(760, 120)})
	_set_area_position(decision_trigger, Vector2(460, 305))
	_set_area_position(exit_area, Vector2(460, 90))

func _build_wolf_road() -> void:
	_set_ground(Color(0.14, 0.34, 0.18, 1.0))
	_add_rect(Vector2(0, 260), Vector2(920, 105), Color(0.67, 0.53, 0.25, 1.0))
	for x in range(70, 900, 105):
		_add_tree(Vector2(x, 120))
		_add_tree(Vector2(x, 500))
	_set_common_challenge(Vector2(80, 310), Vector2(850, 310), Vector2(450, 310))
	enemy_spawn_positions = [Vector2(280, 210), Vector2(390, 420), Vector2(560, 215), Vector2(680, 420)]

func _build_crow_field() -> void:
	_set_ground(Color(0.60, 0.70, 0.38, 1.0))
	_add_rect(Vector2(0, 490), Vector2(920, 55), Color(0.92, 0.77, 0.22, 1.0))
	for x in range(95, 820, 105):
		_add_rect(Vector2(x, 165), Vector2(62, 250), Color(0.35, 0.50, 0.19, 1.0), true)
	_add_circle(Vector2(455, 410), 26.0, Color(0.54, 0.35, 0.17, 1.0))
	_set_common_challenge(Vector2(455, 560), Vector2(455, 65), Vector2(455, 485))
	enemy_spawn_positions = [Vector2(210, 110), Vector2(360, 120), Vector2(520, 110), Vector2(670, 120)]

func _build_bee_hives() -> void:
	_set_ground(Color(0.58, 0.62, 0.30, 1.0))
	for p in [Vector2(210, 210), Vector2(450, 160), Vector2(690, 250), Vector2(365, 420), Vector2(610, 455)]:
		_add_circle(p, 44.0, Color(0.95, 0.80, 0.20, 0.45))
		_add_rect(p - Vector2(18, 22), Vector2(36, 44), Color(0.70, 0.46, 0.14, 1.0), true)
	_set_common_challenge(Vector2(90, 520), Vector2(850, 90), Vector2(445, 315))
	enemy_spawn_positions = [Vector2(240, 210), Vector2(470, 160), Vector2(705, 250), Vector2(390, 420), Vector2(630, 455)]

func _build_winkie_field() -> void:
	_set_ground(Color(0.28, 0.25, 0.22, 1.0))
	_add_rect(Vector2(0, 285), Vector2(920, 70), Color(0.55, 0.42, 0.24, 1.0))
	for p in [Vector2(300, 190), Vector2(300, 430), Vector2(520, 205), Vector2(520, 415)]:
		_add_rect(p, Vector2(90, 45), Color(0.18, 0.16, 0.15, 1.0), true)
	_set_common_challenge(Vector2(80, 320), Vector2(850, 320), Vector2(455, 320))
	enemy_spawn_positions = [Vector2(590, 240), Vector2(650, 240), Vector2(710, 240), Vector2(590, 390), Vector2(650, 390), Vector2(710, 390)]

func _build_flying_monkeys() -> void:
	_set_ground(Color(0.31, 0.36, 0.38, 1.0))
	_set_marker_positions({"lion": Vector2(205, 500), "tin_man": Vector2(720, 500), "scarecrow": Vector2(460, 115)})
	_set_common_challenge(Vector2(90, 320), Vector2(850, 320), Vector2(455, 320))
	enemy_spawn_positions = [Vector2(210, 175), Vector2(460, 155), Vector2(690, 220), Vector2(330, 395), Vector2(610, 430)]

func _build_rescue_prison() -> void:
	_set_ground(Color(0.22, 0.22, 0.24, 1.0))
	_add_rect(Vector2(0, 290), Vector2(920, 70), Color(0.48, 0.43, 0.38, 1.0))
	for p in [Vector2(285, 170), Vector2(500, 170), Vector2(610, 420)]:
		_add_cage(p, Vector2(95, 95))
	_set_common_challenge(Vector2(80, 325), Vector2(850, 325), Vector2(455, 325))
	enemy_spawn_positions = [Vector2(390, 260), Vector2(640, 300), Vector2(520, 505)]

func _build_witch_castle() -> void:
	_set_ground(Color(0.18, 0.16, 0.22, 1.0))
	for r in [Rect2(90, 120, 700, 55), Rect2(90, 445, 700, 55), Rect2(90, 120, 55, 380), Rect2(735, 120, 55, 380), Rect2(300, 175, 55, 230), Rect2(520, 250, 55, 250)]:
		_add_rect(r.position, r.size, Color(0.35, 0.32, 0.42, 1.0))
	_set_common_challenge(Vector2(80, 315), Vector2(850, 315), Vector2(455, 315))
	enemy_spawn_positions = [Vector2(430, 210), Vector2(660, 260), Vector2(420, 430), Vector2(650, 420)]

func _build_witch_defeat_room() -> void:
	_set_ground(Color(0.16, 0.12, 0.16, 1.0))
	_add_rect(Vector2(150, 75), Vector2(620, 470), Color(0.27, 0.22, 0.30, 1.0))
	_add_circle(Vector2(595, 250), 62.0, Color(0.35, 0.04, 0.25, 1.0), "Witch")
	_add_circle(Vector2(355, 375), 34.0, Color(0.20, 0.55, 0.95, 1.0))
	_add_circle(Vector2(595, 250), 105.0, Color(0.75, 0.05, 0.07, 0.25))
	_set_common_challenge(Vector2(215, 500), Vector2(720, 115), Vector2(355, 375))
	enemy_spawn_positions = [Vector2(500, 340), Vector2(675, 335), Vector2(610, 425)]

func _build_return_road() -> void:
	_set_ground(Color(0.25, 0.45, 0.32, 1.0))
	_add_line(Vector2(80, 520), Vector2(820, 95), Color(0.90, 0.74, 0.22, 1.0), 56.0)
	for x in [600, 660, 720, 780]:
		_add_rect(Vector2(x, 55), Vector2(45, 80), Color(0.08, 0.55, 0.25, 1.0))
	_set_common_challenge(Vector2(80, 520), Vector2(835, 90), Vector2(455, 310))
	enemy_spawn_positions = [Vector2(320, 390), Vector2(540, 265)]

func _build_glinda_journey() -> void:
	_set_ground(Color(0.34, 0.54, 0.36, 1.0))
	_add_line(Vector2(80, 545), Vector2(250, 85), Color(0.82, 0.70, 0.32, 1.0), 34.0)
	_add_line(Vector2(80, 545), Vector2(500, 85), Color(0.70, 0.55, 0.28, 1.0), 42.0)
	_add_line(Vector2(80, 545), Vector2(790, 85), Color(0.92, 0.80, 0.42, 1.0), 50.0)
	for p in [Vector2(335, 245), Vector2(470, 335), Vector2(650, 240)]:
		_add_tree(p)
	for p in [Vector2(380, 445), Vector2(560, 380)]:
		_add_rect(p, Vector2(95, 42), Color(0.38, 0.24, 0.14, 1.0), true)
	_add_circle(Vector2(835, 85), 52.0, Color(0.70, 0.92, 1.0, 0.85))
	_set_common_challenge(Vector2(80, 545), Vector2(835, 85), Vector2(445, 340))
	enemy_spawn_positions = [Vector2(250, 170), Vector2(500, 235), Vector2(700, 180), Vector2(585, 430)]

func _build_final_cooperation() -> void:
	_set_ground(Color(0.18, 0.18, 0.22, 1.0))
	_add_rect(Vector2(0, 280), Vector2(920, 70), Color(0.42, 0.38, 0.32, 1.0))
	_add_circle(Vector2(465, 390), 58.0, Color(0.68, 0.71, 0.73, 0.55))
	_add_circle(Vector2(635, 230), 58.0, Color(0.54, 0.35, 0.17, 0.55))
	_add_rect(Vector2(420, 260), Vector2(95, 95), Color(0.80, 0.06, 0.08, 0.28))
	_set_common_challenge(Vector2(80, 315), Vector2(850, 315), Vector2(455, 315))
	enemy_spawn_positions = [Vector2(300, 310), Vector2(455, 250), Vector2(610, 315), Vector2(455, 450), Vector2(720, 220)]

func _build_generic_scene(scenario_type: String) -> void:
	_set_ground(Color(0.16, 0.39, 0.25, 1.0))
	if scenario_type == "final_test":
		_set_ground(Color(0.24, 0.24, 0.38, 1.0))
	elif scenario_type == "test":
		_set_ground(Color(0.30, 0.23, 0.30, 1.0))
	_add_rect(Vector2(0, 280), Vector2(920, 70), Color(0.82, 0.72, 0.30, 1.0))
	_set_common_challenge(Vector2(90, 315), Vector2(850, 315), Vector2(455, 315))
	enemy_spawn_positions = [Vector2(560, 300)]

func _set_common_challenge(player_pos: Vector2, exit_pos: Vector2, trigger_pos: Vector2) -> void:
	_set_marker_positions({
		"dorothy": player_pos,
		"lion": player_pos + Vector2(60, -35),
		"tin_man": player_pos + Vector2(-55, -10),
		"scarecrow": player_pos + Vector2(-75, 42),
		"enemy": trigger_pos + Vector2(170, 0),
	})
	_set_area_position(decision_trigger, trigger_pos)
	_set_area_position(exit_area, exit_pos)

func _ensure_visual_root() -> void:
	visual_root = get_node_or_null("GeneratedVisuals") as Node2D
	if visual_root == null:
		visual_root = Node2D.new()
		visual_root.name = "GeneratedVisuals"
		add_child(visual_root)
		move_child(visual_root, 1)

func _clear_visuals() -> void:
	for child in visual_root.get_children():
		child.queue_free()

func _set_ground(color: Color) -> void:
	if has_node("Ground"):
		$Ground.color = color
		$Ground.offset_left = -20.0
		$Ground.offset_top = -20.0
		$Ground.offset_right = MAP_SIZE.x
		$Ground.offset_bottom = MAP_SIZE.y

func _add_rect(pos: Vector2, size: Vector2, color: Color, collides: bool = false, node_name: String = "") -> Node:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	if not node_name.is_empty():
		rect.name = node_name
		special_nodes[node_name] = [rect]
	visual_root.add_child(rect)
	if collides:
		var body := StaticBody2D.new()
		if not node_name.is_empty():
			body.name = "%sCollision" % node_name
		body.position = pos + size * 0.5
		var shape := CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = size
		shape.shape = rect_shape
		body.add_child(shape)
		visual_root.add_child(body)
		if not node_name.is_empty():
			special_nodes[node_name].append(body)
	return rect

func _add_circle(center: Vector2, radius: float, color: Color, node_name: String = "") -> Polygon2D:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = points
	circle.position = center
	circle.color = color
	if not node_name.is_empty():
		circle.name = node_name
		special_nodes[node_name] = [circle]
	visual_root.add_child(circle)
	return circle

func _add_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float = 4.0, node_name: String = "") -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([from_pos, to_pos])
	line.default_color = color
	line.width = width
	if not node_name.is_empty():
		line.name = node_name
		special_nodes[node_name] = [line]
	visual_root.add_child(line)
	return line

func _add_tree(center: Vector2) -> void:
	_add_rect(center + Vector2(-8, 12), Vector2(16, 32), Color(0.32, 0.18, 0.09, 1.0), true)
	_add_circle(center, 32.0, Color(0.08, 0.42, 0.16, 1.0))

func _add_cage(pos: Vector2, size: Vector2) -> void:
	_add_rect(pos, size, Color(0.10, 0.10, 0.12, 0.25), true)
	for offset in range(0, int(size.x) + 1, 18):
		_add_line(pos + Vector2(offset, 0), pos + Vector2(offset, size.y), Color(0.65, 0.65, 0.68, 1.0), 3.0)
	_add_line(pos, pos + Vector2(size.x, 0), Color(0.65, 0.65, 0.68, 1.0), 3.0)
	_add_line(pos + Vector2(0, size.y), pos + size, Color(0.65, 0.65, 0.68, 1.0), 3.0)

func _set_marker_positions(positions: Dictionary) -> void:
	for marker_id in positions.keys():
		_move_marker(str(marker_id), positions[marker_id])

func _move_marker(marker_id: String, pos: Vector2) -> void:
	var marker := get_node_or_null("Spawns/%s" % marker_id) as Node2D
	if marker:
		marker.position = pos

func _set_area_position(area: Area2D, pos: Vector2) -> void:
	if area:
		area.position = pos

func _hide_special(node_name: String) -> void:
	if not special_nodes.has(node_name):
		return
	for node in special_nodes[node_name]:
		if is_instance_valid(node):
			node.visible = false
			var collision_shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collision_shape:
				collision_shape.set_deferred("disabled", true)

func _show_result_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(260, 40)
	label.add_theme_font_size_override("font_size", 18)
	visual_root.add_child(label)

func _highlight_route(color: Color) -> void:
	_add_line(Vector2(465, 500), Vector2(700, 90), color, 12.0, "ChosenRoute")

func _on_decision_trigger_body_entered(body: Node) -> void:
	if decision_was_triggered or challenge_was_triggered or not body.is_in_group("player"):
		return

	if requires_decision:
		decision_was_triggered = true
		decision_triggered.emit()
	else:
		challenge_was_triggered = true
		challenge_triggered.emit()
		get_tree().create_timer(2.0).timeout.connect(mark_completed)

func _on_exit_body_entered(body: Node) -> void:
	if completed and body.is_in_group("player"):
		exit_reached.emit()

func _set_area_enabled(area: Area2D, enabled: bool) -> void:
	if area == null:
		return
	area.visible = enabled
	var collision_shape: CollisionShape2D = area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.set_deferred("disabled", not enabled)

func _set_area_label_visible(area: Area2D, is_visible: bool) -> void:
	if area == null:
		return
	var label: Label = area.get_node_or_null("Label") as Label
	if label:
		label.visible = is_visible

func _set_area_label_text(area: Area2D, text: String) -> void:
	if area == null:
		return
	var label: Label = area.get_node_or_null("Label") as Label
	if label:
		label.text = text
