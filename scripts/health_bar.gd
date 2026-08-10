extends Control

const BAR_WIDTH = 220.0
const BAR_HEIGHT = 26.0
const MARGIN = 20.0

const NORMAL_COLOR = Color(0.75, 0.15, 0.15)
const MIRROR_COLOR = Color(0.2, 0.45, 0.9)

var player: Node = null

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var label: Label = $Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	background.color = Color(0.1, 0.05, 0.05, 0.85)
	fill.color = Color(0.75, 0.15, 0.15)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	call_deferred("_connect_to_player")
	call_deferred("_layout")


func _layout() -> void:
	var vp_size = get_viewport_rect().size
	var origin = Vector2(vp_size.x - BAR_WIDTH - MARGIN, vp_size.y - BAR_HEIGHT - MARGIN)

	background.position = origin
	background.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	fill.position = origin
	fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	label.position = origin
	label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)


func _connect_to_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	player = players[0]
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.mirror_world_changed.connect(_on_mirror_world_changed)
	_on_health_changed(player.health, player.MAX_HEALTH)


func _on_health_changed(current: int, max_health: int) -> void:
	var ratio = float(current) / float(max_health)
	fill.size.x = BAR_WIDTH * ratio
	label.text = "HP  %d / %d" % [current, max_health]


func _on_mirror_world_changed(active: bool) -> void:
	fill.color = MIRROR_COLOR if active else NORMAL_COLOR


func _on_player_died() -> void:
	fill.size.x = 0
	label.text = "HP  0 / %d" % player.MAX_HEALTH
