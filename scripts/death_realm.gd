extends Node2D

@onready var start_marker: Marker2D = $StartMarker
@onready var void_catch: Area2D = $VoidCatch


func _ready() -> void:
	void_catch.body_entered.connect(_on_void_catch_body_entered)


func _on_void_catch_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.global_position = start_marker.global_position
	body.velocity = Vector2.ZERO
