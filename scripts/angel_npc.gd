extends Node2D

const BOB_AMPLITUDE := 6.0
const BOB_SPEED := 1.6
const DIALOGUE_LINES := [
	"...",
	"이곳까지 오다니, 흔치 않은 일이야.",
	"두려워하지 마. 여긴 잠시 쉬어가는 곳이니까.",
	"준비가 되면, 다시 돌아갈 길을 찾게 될 거야.",
]

var _time := 0.0
var _base_y := 0.0
var _player_in_range := false
var _player: Node = null
var _dialogue_open := false
var _dialogue_index := 0

@onready var visual: Node2D = $Visual
@onready var detection_area: Area2D = $DetectionArea
@onready var prompt_label: Label = $PromptLabel

var _dialogue_layer: CanvasLayer
var _dialogue_panel: Panel
var _dialogue_label: Label


func _ready() -> void:
	_base_y = visual.position.y
	_build_visual()
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	prompt_label.visible = false
	prompt_label.text = "F"
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_dialogue_ui()


func _build_visual() -> void:
	var left_wing := Polygon2D.new()
	left_wing.color = Color(0.88, 0.92, 1.0, 0.85)
	left_wing.polygon = PackedVector2Array([
		Vector2(-2, -14), Vector2(-32, -34), Vector2(-36, -2), Vector2(-16, 16), Vector2(-4, 6)
	])
	visual.add_child(left_wing)

	var right_wing := Polygon2D.new()
	right_wing.color = Color(0.88, 0.92, 1.0, 0.85)
	right_wing.polygon = PackedVector2Array([
		Vector2(2, -14), Vector2(32, -34), Vector2(36, -2), Vector2(16, 16), Vector2(4, 6)
	])
	visual.add_child(right_wing)

	var robe := Polygon2D.new()
	robe.color = Color(0.97, 0.96, 0.92, 0.98)
	robe.polygon = PackedVector2Array([
		Vector2(-8, -30), Vector2(8, -30), Vector2(15, 12), Vector2(-15, 12)
	])
	visual.add_child(robe)

	var head := Polygon2D.new()
	head.color = Color(0.98, 0.93, 0.85, 1.0)
	var head_pts := PackedVector2Array()
	for i in range(12):
		var a := (TAU / 12.0) * i
		head_pts.append(Vector2(cos(a), sin(a)) * 7.0 + Vector2(0, -38))
	head.polygon = head_pts
	visual.add_child(head)

	var halo := Line2D.new()
	halo.width = 2.0
	halo.default_color = Color(1.0, 0.92, 0.55, 0.9)
	var halo_pts := PackedVector2Array()
	for i in range(17):
		var a := (TAU / 16.0) * i
		halo_pts.append(Vector2(cos(a) * 11.0, -50.0 + sin(a) * 4.0))
	halo.points = halo_pts
	visual.add_child(halo)


func _process(delta: float) -> void:
	_time += delta
	visual.position.y = _base_y + sin(_time * BOB_SPEED) * BOB_AMPLITUDE

	if _player_in_range and not _dialogue_open and Input.is_action_just_pressed("talk"):
		_open_dialogue()
	elif _dialogue_open and Input.is_action_just_pressed("talk"):
		_advance_dialogue()


func _on_detection_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player = body
	_player_in_range = true
	if not _dialogue_open:
		prompt_label.visible = true


func _on_detection_body_exited(body: Node) -> void:
	if body != _player:
		return
	_player_in_range = false
	prompt_label.visible = false
	if _dialogue_open:
		_close_dialogue()


func _open_dialogue() -> void:
	_dialogue_open = true
	_dialogue_index = 0
	prompt_label.visible = false
	if _player:
		_player.is_transitioning = true
		_player.set_physics_process(false)
	_dialogue_layer.visible = true
	_dialogue_label.text = DIALOGUE_LINES[_dialogue_index]


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= DIALOGUE_LINES.size():
		_close_dialogue()
		return
	_dialogue_label.text = DIALOGUE_LINES[_dialogue_index]


func _close_dialogue() -> void:
	_dialogue_open = false
	_dialogue_layer.visible = false
	if _player:
		_player.set_physics_process(true)
		_player.is_transitioning = false
	if _player_in_range:
		prompt_label.visible = true


func _build_dialogue_ui() -> void:
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.layer = 50
	_dialogue_layer.visible = false
	add_child(_dialogue_layer)

	_dialogue_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.85)
	style.border_color = Color(1, 1, 1, 0.25)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_dialogue_panel.add_theme_stylebox_override("panel", style)
	_dialogue_panel.position = Vector2(80, 420)
	_dialogue_panel.size = Vector2(800, 90)
	_dialogue_layer.add_child(_dialogue_panel)

	_dialogue_label = Label.new()
	_dialogue_label.position = Vector2(20, 10)
	_dialogue_label.size = Vector2(700, 70)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_size_override("font_size", 18)
	_dialogue_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_dialogue_panel.add_child(_dialogue_label)

	_build_portrait()


func _build_portrait() -> void:
	var portrait_root := Node2D.new()
	portrait_root.position = Vector2(840, 400)
	_dialogue_layer.add_child(portrait_root)

	var frame := Polygon2D.new()
	frame.color = Color(0.05, 0.06, 0.1, 0.95)
	var frame_pts := PackedVector2Array()
	for i in range(20):
		var fa := (TAU / 20.0) * i
		frame_pts.append(Vector2(cos(fa), sin(fa)) * 34.0)
	frame.polygon = frame_pts
	portrait_root.add_child(frame)

	var frame_ring := Line2D.new()
	frame_ring.width = 2.5
	frame_ring.default_color = Color(1.0, 0.92, 0.6, 0.9)
	var ring_pts := PackedVector2Array()
	for i in range(21):
		var ra := (TAU / 20.0) * i
		ring_pts.append(Vector2(cos(ra), sin(ra)) * 34.0)
	frame_ring.points = ring_pts
	portrait_root.add_child(frame_ring)

	var halo := Line2D.new()
	halo.width = 2.0
	halo.default_color = Color(1.0, 0.92, 0.55, 0.9)
	var halo_pts := PackedVector2Array()
	for i in range(17):
		var ha := (TAU / 16.0) * i
		halo_pts.append(Vector2(cos(ha) * 12.0, -26.0 + sin(ha) * 3.5))
	halo.points = halo_pts
	portrait_root.add_child(halo)

	var hair := Polygon2D.new()
	hair.color = Color(0.92, 0.85, 0.55, 1.0)
	hair.polygon = PackedVector2Array([
		Vector2(-16, -4), Vector2(-14, -16), Vector2(0, -20), Vector2(14, -16), Vector2(16, -4),
		Vector2(10, -8), Vector2(0, -10), Vector2(-10, -8),
	])
	portrait_root.add_child(hair)

	var head := Polygon2D.new()
	head.color = Color(0.98, 0.93, 0.85, 1.0)
	var head_pts := PackedVector2Array()
	for i in range(16):
		var a := (TAU / 16.0) * i
		head_pts.append(Vector2(cos(a), sin(a)) * 16.0)
	head.polygon = head_pts
	portrait_root.add_child(head)

	var left_eye := Polygon2D.new()
	left_eye.color = Color(0.15, 0.15, 0.2, 1.0)
	left_eye.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
	left_eye.position = Vector2(-6, 1)
	portrait_root.add_child(left_eye)

	var right_eye: Polygon2D = left_eye.duplicate()
	right_eye.position = Vector2(6, 1)
	portrait_root.add_child(right_eye)

	var mouth := Line2D.new()
	mouth.width = 1.5
	mouth.default_color = Color(0.6, 0.35, 0.3, 0.9)
	mouth.points = PackedVector2Array([Vector2(-4, 8), Vector2(0, 10), Vector2(4, 8)])
	portrait_root.add_child(mouth)
