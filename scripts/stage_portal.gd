extends Area2D

@export var target_stage: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
@export var heal_to_full: bool = false

var _triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	body.is_transitioning = true
	body.set_physics_process(false)

	var stage: String = target_stage if target_stage != "" else GameState.last_stage_before_transition
	var health: int = body.MAX_HEALTH if heal_to_full else body.health
	GameState.return_to_stage(stage, spawn_position, health)
