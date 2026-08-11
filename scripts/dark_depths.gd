extends Node2D

const STAR_COUNT := 45
const STAR_FIELD_MIN := Vector2(-60.0, -150.0)
const STAR_FIELD_MAX := Vector2(1300.0, 500.0)

@onready var start_marker: Marker2D = $StartMarker
@onready var void_catch: Area2D = $VoidCatch
@onready var stars: Node2D = $Stars


func _ready() -> void:
	_scatter_stars()
	void_catch.body_entered.connect(_on_void_catch_body_entered)


func _scatter_stars() -> void:
	var star_tex := _make_star_texture()
	for i in range(STAR_COUNT):
		var star := Sprite2D.new()
		star.texture = star_tex
		star.position = Vector2(
			randf_range(STAR_FIELD_MIN.x, STAR_FIELD_MAX.x),
			randf_range(STAR_FIELD_MIN.y, STAR_FIELD_MAX.y)
		)
		star.modulate = Color(0.8, 0.85, 1.0, randf_range(0.2, 0.75))
		star.scale = Vector2.ONE * randf_range(0.5, 1.5)
		stars.add_child(star)


func _make_star_texture() -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _on_void_catch_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	body.global_position = start_marker.global_position
	body.velocity = Vector2.ZERO
