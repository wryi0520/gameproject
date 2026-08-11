extends Control

const CLOUD_COUNT := 5

const MENU_SHOWN_X := 380.0
const MENU_HIDDEN_X := MENU_SHOWN_X - 960.0
const PANEL_SHOWN_X := 350.0
const PANEL_HIDDEN_X := PANEL_SHOWN_X + 960.0
const SLIDE_DURATION := 0.4

var _clouds: Array = []
var _cloud_texture: ImageTexture
var _menu_container: Control
var _settings_panel: Control
var _menu_tween: Tween
var _panel_tween: Tween

func _ready() -> void:
	randomize()
	_cloud_texture = _make_cloud_texture()
	_spawn_clouds()
	_setup_snow()
	GameState.fade_in_current()

	_menu_container = $MenuContainer
	_settings_panel = $SettingsPanel
	_settings_panel.position.x = PANEL_HIDDEN_X

	$MenuContainer/StartButton.pressed.connect(_on_start_pressed)
	$MenuContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$MenuContainer/ExtraButton.pressed.connect(_on_extra_pressed)
	$MenuContainer/QuitButton.pressed.connect(_on_quit_pressed)
	_settings_panel.get_node("CloseButton").pressed.connect(_on_settings_close_pressed)

	var volume_slider: HSlider = _settings_panel.get_node("VolumeSlider")
	volume_slider.value = GameState.master_volume
	volume_slider.value_changed.connect(GameState.set_master_volume)

	var brightness_slider: HSlider = _settings_panel.get_node("BrightnessSlider")
	brightness_slider.value = GameState.brightness
	brightness_slider.value_changed.connect(GameState.set_brightness)

func _process(delta: float) -> void:
	for cloud in _clouds:
		var sprite: Sprite2D = cloud["sprite"]
		sprite.position.x += cloud["speed"] * delta
		if sprite.position.x - cloud["half_width"] > 1020.0:
			sprite.position.x = -cloud["half_width"] - randf() * 200.0

func _spawn_clouds() -> void:
	var layer: Node2D = $Clouds
	var presets := [
		{"y": 55.0, "scale": 1.3, "speed": 7.0},
		{"y": 95.0, "scale": 0.8, "speed": 12.0},
		{"y": 135.0, "scale": 1.6, "speed": 5.0},
		{"y": 40.0, "scale": 1.0, "speed": 9.5},
		{"y": 165.0, "scale": 0.9, "speed": 8.0},
	]
	for i in range(CLOUD_COUNT):
		var preset: Dictionary = presets[i]
		var sprite := Sprite2D.new()
		sprite.texture = _cloud_texture
		sprite.centered = false
		sprite.scale = Vector2.ONE * preset["scale"]
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.88)
		sprite.position = Vector2(randf_range(-100.0, 900.0), preset["y"])
		layer.add_child(sprite)
		_clouds.append({
			"sprite": sprite,
			"speed": preset["speed"],
			"half_width": _cloud_texture.get_width() * preset["scale"] * 0.5,
		})

func _make_cloud_texture() -> ImageTexture:
	var w := 60
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var puffs := [
		Vector2(14, 15), Vector2(22, 9), Vector2(30, 11),
		Vector2(38, 14), Vector2(46, 12), Vector2(10, 18), Vector2(50, 18),
	]
	for x in range(w):
		for y in range(h):
			for p in puffs:
				if Vector2(x, y).distance_to(p) < 8.5:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
					break
	return ImageTexture.create_from_image(img)

func _setup_snow() -> void:
	var snow: CPUParticles2D = $Snow
	var flake := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	flake.fill(Color(1, 1, 1, 1))
	snow.texture = ImageTexture.create_from_image(flake)
	snow.amount = 90
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.emitting = true
	snow.position = Vector2(480, -20)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(480, 4)
	snow.direction = Vector2(0, 1)
	snow.spread = 15.0
	snow.gravity = Vector2(0, 22)
	snow.initial_velocity_min = 18.0
	snow.initial_velocity_max = 36.0
	snow.tangential_accel_min = -20.0
	snow.tangential_accel_max = 20.0
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.4
	snow.color = Color(1, 1, 1, 0.85)
	snow.angular_velocity_min = -40.0
	snow.angular_velocity_max = 40.0

func _on_start_pressed() -> void:
	GameState.goto_scene("res://scenes/StageSelect.tscn")

func _on_settings_pressed() -> void:
	_slide_menu(MENU_HIDDEN_X)
	_slide_panel(PANEL_SHOWN_X)

func _on_settings_close_pressed() -> void:
	_slide_panel(PANEL_HIDDEN_X)
	_slide_menu(MENU_SHOWN_X)

func _slide_menu(target_x: float) -> void:
	if _menu_tween and _menu_tween.is_valid():
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_property(_menu_container, "position:x", target_x, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _slide_panel(target_x: float) -> void:
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_settings_panel, "position:x", target_x, SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_extra_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
