extends Area2D

@export var return_spawn_offset: Vector2 = Vector2(-30, 20)

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	body.is_transitioning = true
	body.set_physics_process(false)

	GameState.angel_return_stage = get_tree().current_scene.scene_file_path
	GameState.angel_return_spawn = global_position + return_spawn_offset

	GameState.goto_scene("res://scenes/AngelRoom.tscn")
