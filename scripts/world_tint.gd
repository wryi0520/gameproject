extends CanvasModulate

const NORMAL_TINT = Color(1.0, 1.0, 1.0)
const MIRROR_TINT = Color(0.82, 0.85, 1.0)


func _ready() -> void:
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		players[0].mirror_world_changed.connect(_on_mirror_world_changed)


func _on_mirror_world_changed(active: bool) -> void:
	var target = MIRROR_TINT if active else NORMAL_TINT
	var tween = create_tween()
	tween.tween_property(self, "color", target, 0.4)
