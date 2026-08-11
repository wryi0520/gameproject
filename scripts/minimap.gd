extends Control

const MAP_WIDTH = 220.0
const MAP_HEIGHT = 70.0
const MARGIN = 16.0

const WORLD_X_MIN = 0.0
const WORLD_X_MAX = 4550.0
const WORLD_Y_MIN = 370.0
const WORLD_Y_MAX = 530.0

const PLATFORMS = [
	[0.0, 750.0, 500.0],
	[830.0, 950.0, 480.0],
	[950.0, 1070.0, 520.0],
	[1070.0, 1190.0, 555.0],
	[1190.0, 1310.0, 555.0],
	[1310.0, 1430.0, 520.0],
	[1430.0, 1550.0, 480.0],
	[1630.0, 2400.0, 500.0],
	[300.0, 560.0, 400.0],
	[950.0, 1260.0, 380.0],
	[1750.0, 2010.0, 460.0],
	[2480.0, 2600.0, 480.0],
	[2600.0, 2720.0, 440.0],
	[2720.0, 2840.0, 400.0],
	[2840.0, 2960.0, 400.0],
	[2960.0, 3080.0, 440.0],
	[3080.0, 3200.0, 480.0],
	[3320.0, 3400.0, 460.0],
	[3450.0, 3530.0, 400.0],
	[3620.0, 3700.0, 460.0],
	[3740.0, 4510.0, 480.0],
]

var player: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_connect_to_player")
	call_deferred("_layout")


func _layout() -> void:
	var vp_size = get_viewport_rect().size
	position = Vector2(vp_size.x - MAP_WIDTH - MARGIN, MARGIN)
	custom_minimum_size = Vector2(MAP_WIDTH, MAP_HEIGHT)
	size = Vector2(MAP_WIDTH, MAP_HEIGHT)


func _connect_to_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0]


func _map_x(world_x: float) -> float:
	var t = (world_x - WORLD_X_MIN) / (WORLD_X_MAX - WORLD_X_MIN)
	return clamp(t, 0.0, 1.0) * MAP_WIDTH


func _map_y(world_y: float) -> float:
	var t = (world_y - WORLD_Y_MIN) / (WORLD_Y_MAX - WORLD_Y_MIN)
	return clamp(t, 0.0, 1.0) * MAP_HEIGHT


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)), Color(0.05, 0.06, 0.09, 0.75))
	draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_WIDTH, MAP_HEIGHT)), Color(0.4, 0.45, 0.5, 0.9), false, 1.5)

	for platform in PLATFORMS:
		var x1 = _map_x(platform[0])
		var x2 = _map_x(platform[1])
		var y = _map_y(platform[2])
		draw_line(Vector2(x1, y), Vector2(x2, y), Color(0.55, 0.6, 0.65), 2.0)

	if player and is_instance_valid(player):
		var px = _map_x(player.global_position.x)
		var py = _map_y(player.global_position.y)
		draw_circle(Vector2(px, py), 4.0, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(px, py), 2.5, Color(1.0, 0.85, 0.2))
