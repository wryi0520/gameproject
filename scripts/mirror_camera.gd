extends Camera2D

const RECESSION = 0.8   # zoomed out relative to the main camera, so the reflection reads as "deeper" / farther away
const SHIMMER_AMPLITUDE = 0.006
const SHIMMER_SPEED = 1.3

var main_camera: Camera2D = null
var time := 0.0


func _ready() -> void:
	enabled = true
	call_deferred("_find_main_camera")


func _find_main_camera() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		main_camera = players[0].get_node("Camera2D")


func _process(delta: float) -> void:
	if main_camera == null or not is_instance_valid(main_camera):
		return
	time += delta
	global_position = main_camera.global_position.round()
	zoom = main_camera.zoom * RECESSION
	scale.x = -1.0
	rotation = sin(time * SHIMMER_SPEED) * SHIMMER_AMPLITUDE
