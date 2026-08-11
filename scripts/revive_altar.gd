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
	GameState.return_to_stage(GameState.last_stage_before_transition, GameState.pending_spawn, body.MAX_HEALTH)
