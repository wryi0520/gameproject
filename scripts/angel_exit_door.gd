extends Area2D

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	body.is_transitioning = true
	body.set_physics_process(false)

	var stage: String = GameState.angel_return_stage if GameState.angel_return_stage != "" else GameState.MAIN_STAGE
	GameState.return_to_stage(stage, GameState.angel_return_spawn, body.health)
