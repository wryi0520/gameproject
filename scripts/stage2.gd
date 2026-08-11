extends Node2D

@onready var mirror_viewport: SubViewport = $MirrorViewport
@onready var mirror_display: TextureRect = $MirrorBackdrop/MirrorDisplay


func _ready() -> void:
	mirror_viewport.world_2d = get_viewport().world_2d
	mirror_display.texture = mirror_viewport.get_texture()
	mirror_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	mirror_display.stretch_mode = TextureRect.STRETCH_SCALE
	mirror_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mirror_display.modulate = Color(0.32, 0.36, 0.5, 0.55)
