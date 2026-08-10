extends ColorRect

const MIRROR_FLASH_COLOR = Color(0.75, 0.85, 1.0, 0.55)
const NORMAL_FLASH_COLOR = Color(1.0, 1.0, 1.0, 0.5)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(1, 1, 1, 0)
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		players[0].mirror_world_changed.connect(_on_mirror_world_changed)


func _on_mirror_world_changed(active: bool) -> void:
	color = MIRROR_FLASH_COLOR if active else NORMAL_FLASH_COLOR
	var tween = create_tween()
	tween.tween_property(self, "color:a", 0.0, 0.3)
