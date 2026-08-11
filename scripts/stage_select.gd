extends Control

const STAGES := [
	{"name": "Stage 1", "scene": "res://scenes/Stage1.tscn", "unlocked": true},
	{"name": "Stage 2", "scene": "res://scenes/Stage2.tscn", "unlocked": true},
	{"name": "Stage 3", "scene": "", "unlocked": false},
	{"name": "Stage 4", "scene": "", "unlocked": false},
]

const BOX_SIZE := 110.0
const BOX_GAP := 30.0

func _ready() -> void:
	GameState.fade_in_current()
	_build_stage_grid()
	$BackButton.pressed.connect(_on_back_pressed)

func _build_stage_grid() -> void:
	var grid: Control = $StageGrid
	var total_width: float = STAGES.size() * BOX_SIZE + (STAGES.size() - 1) * BOX_GAP
	var start_x: float = (960.0 - total_width) * 0.5

	for i in range(STAGES.size()):
		var stage: Dictionary = STAGES[i]
		var box := Button.new()
		box.name = "StageBox%d" % (i + 1)
		box.position = Vector2(start_x + i * (BOX_SIZE + BOX_GAP), 0.0)
		box.custom_minimum_size = Vector2(BOX_SIZE, BOX_SIZE)
		box.size = Vector2(BOX_SIZE, BOX_SIZE)
		box.text = stage["name"] if stage["unlocked"] else "LOCKED"
		box.add_theme_font_size_override("font_size", 14)

		var normal_style := StyleBoxFlat.new()
		var hover_style := StyleBoxFlat.new()
		var pressed_style := StyleBoxFlat.new()
		var disabled_style := StyleBoxFlat.new()

		if stage["unlocked"]:
			normal_style.bg_color = Color(0.55, 0.55, 0.58, 0.55)
			hover_style.bg_color = Color(0.68, 0.68, 0.72, 0.62)
			pressed_style.bg_color = Color(0.42, 0.42, 0.45, 0.6)
			disabled_style.bg_color = Color(0.55, 0.55, 0.58, 0.55)
			var border_col := Color(1, 1, 1, 0.28)
			normal_style.border_color = border_col
			hover_style.border_color = border_col
			pressed_style.border_color = border_col
			disabled_style.border_color = border_col
			box.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
			box.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6))
		else:
			normal_style.bg_color = Color(0, 0, 0, 0.55)
			hover_style.bg_color = Color(0, 0, 0, 0.55)
			pressed_style.bg_color = Color(0, 0, 0, 0.55)
			disabled_style.bg_color = Color(0, 0, 0, 0.55)
			var border_col_locked := Color(1, 1, 1, 0.12)
			normal_style.border_color = border_col_locked
			hover_style.border_color = border_col_locked
			pressed_style.border_color = border_col_locked
			disabled_style.border_color = border_col_locked
			box.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))

		for style in [normal_style, hover_style, pressed_style, disabled_style]:
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6

		box.add_theme_stylebox_override("normal", normal_style)
		box.add_theme_stylebox_override("hover", hover_style)
		box.add_theme_stylebox_override("pressed", pressed_style)
		box.add_theme_stylebox_override("disabled", disabled_style)

		if stage["unlocked"]:
			box.pressed.connect(_on_stage_pressed.bind(stage["scene"]))
		else:
			box.disabled = true

		grid.add_child(box)

func _on_stage_pressed(scene_path: String) -> void:
	GameState.goto_scene(scene_path)

func _on_back_pressed() -> void:
	GameState.goto_scene("res://scenes/Title.tscn")
