extends Node

const MAIN_STAGE := "res://scenes/Stage2.tscn"
const FALL_STAGE := "res://scenes/DarkDepths.tscn"
const DEATH_STAGE := "res://scenes/DeathRealm.tscn"
const DEATH_REALM_HEALTH := 3

var last_stage_before_transition := MAIN_STAGE
var pending_spawn := Vector2.ZERO
var pending_health := -1
var has_pending_spawn := false

var angel_return_stage := ""
var angel_return_spawn := Vector2.ZERO

const MIN_LOADING_TIME := 0.5

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _loading_label: Label
var _busy := false

var master_volume := 80.0
var brightness := 100.0

var _brightness_overlay: ColorRect
var _pause_layer: CanvasLayer
var _pause_dim: ColorRect
var _pause_panel: VBoxContainer
var _pause_settings_panel: VBoxContainer
var _paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_layer()
	_build_brightness_layer()
	_build_pause_layer()
	set_master_volume(master_volume)


func _process(_delta: float) -> void:
	if _loading_label.visible:
		var dots := (Time.get_ticks_msec() / 300) % 4
		_loading_label.text = "Loading" + ".".repeat(dots)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_try_toggle_pause()


func _build_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)

	_loading_label = Label.new()
	_loading_label.text = "Loading"
	_loading_label.visible = false
	_loading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.position = Vector2(0, 0)
	_loading_label.size = Vector2(960, 540)
	_loading_label.add_theme_font_size_override("font_size", 22)
	_loading_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_fade_layer.add_child(_loading_label)


func goto_scene(path: String, flash_color := Color(0, 0, 0)) -> void:
	if _busy:
		return
	_travel(path, flash_color)


func fade_in_current() -> void:
	_fade_rect.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.6)


func fall_into_depths(from_stage: String, current_health: int) -> void:
	if _busy:
		return
	last_stage_before_transition = from_stage
	has_pending_spawn = false
	pending_health = current_health
	_travel(FALL_STAGE, Color(0.02, 0.02, 0.05))


func die_into_death_realm(from_stage: String, death_position: Vector2) -> void:
	if _busy:
		return
	last_stage_before_transition = from_stage
	pending_spawn = death_position
	has_pending_spawn = false
	pending_health = DEATH_REALM_HEALTH
	_travel(DEATH_STAGE, Color(0, 0, 0))


func return_to_stage(stage_path: String, spawn_position: Vector2, health: int) -> void:
	if _busy:
		return
	pending_spawn = spawn_position
	has_pending_spawn = true
	pending_health = health
	_travel(stage_path, Color(1, 1, 1))


func consume_spawn() -> Vector2:
	has_pending_spawn = false
	return pending_spawn


func consume_health() -> int:
	var h := pending_health
	pending_health = -1
	return h


func _travel(path: String, flash_color: Color) -> void:
	if _paused:
		resume_game()
	_busy = true
	var tree := get_tree()
	var start_time := Time.get_ticks_msec()

	_fade_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	var tween_out := create_tween()
	tween_out.tween_property(_fade_rect, "color:a", 1.0, 0.4)
	await tween_out.finished

	_loading_label.visible = true

	tree.change_scene_to_file(path)
	await tree.process_frame
	await tree.process_frame

	var elapsed := Time.get_ticks_msec() - start_time
	var remaining := MIN_LOADING_TIME * 1000.0 - elapsed
	if remaining > 0.0:
		await tree.create_timer(remaining / 1000.0).timeout

	_loading_label.visible = false

	var tween_in := create_tween()
	tween_in.tween_property(_fade_rect, "color:a", 0.0, 0.5)
	await tween_in.finished
	_busy = false


func _build_brightness_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)

	_brightness_overlay = ColorRect.new()
	_brightness_overlay.color = Color(0, 0, 0, 0)
	_brightness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_brightness_overlay)


func set_master_volume(value: float) -> void:
	master_volume = value
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(value / 100.0, 0.0001, 1.0)))


func set_brightness(value: float) -> void:
	brightness = value
	if _brightness_overlay:
		_brightness_overlay.color.a = (100.0 - value) / 100.0 * 0.7


func _try_toggle_pause() -> void:
	if _busy:
		return
	if get_tree().get_nodes_in_group("player").is_empty():
		return
	if _paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	if _paused:
		return
	_paused = true
	get_tree().paused = true
	_pause_layer.visible = true
	_show_pause_main()


func resume_game() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	_pause_layer.visible = false


func _show_pause_main() -> void:
	_pause_panel.visible = true
	_pause_settings_panel.visible = false


func _show_pause_settings() -> void:
	_pause_panel.visible = false
	_pause_settings_panel.visible = true


func _build_pause_layer() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 95
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	add_child(_pause_layer)

	_pause_dim = ColorRect.new()
	_pause_dim.color = Color(0, 0, 0, 0.6)
	_pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(_pause_dim)

	_pause_panel = _make_pause_main_panel()
	_pause_layer.add_child(_pause_panel)

	_pause_settings_panel = _make_pause_settings_panel()
	_pause_settings_panel.visible = false
	_pause_layer.add_child(_pause_settings_panel)


func _make_pause_main_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(380, 160)
	box.size = Vector2(200, 280)
	box.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "일시정지"
	title.custom_minimum_size = Vector2(200, 0)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var resume_btn := _make_menu_button("계속 플레이")
	resume_btn.pressed.connect(resume_game)
	box.add_child(resume_btn)

	var settings_btn := _make_menu_button("설정")
	settings_btn.pressed.connect(_show_pause_settings)
	box.add_child(settings_btn)

	var main_menu_btn := _make_menu_button("메인화면")
	main_menu_btn.pressed.connect(_on_pause_main_menu_pressed)
	box.add_child(main_menu_btn)

	var quit_btn := _make_menu_button("종료")
	quit_btn.pressed.connect(_on_pause_quit_pressed)
	box.add_child(quit_btn)

	return box


func _make_pause_settings_panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(360, 160)
	box.size = Vector2(240, 280)
	box.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "설정"
	title.custom_minimum_size = Vector2(240, 0)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var vol_label := Label.new()
	vol_label.text = "음량"
	vol_label.add_theme_font_size_override("font_size", 16)
	vol_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.97, 1))
	box.add_child(vol_label)

	var vol_slider := HSlider.new()
	vol_slider.min_value = 0
	vol_slider.max_value = 100
	vol_slider.value = master_volume
	vol_slider.custom_minimum_size = Vector2(220, 20)
	vol_slider.value_changed.connect(set_master_volume)
	box.add_child(vol_slider)

	var bright_label := Label.new()
	bright_label.text = "밝기"
	bright_label.add_theme_font_size_override("font_size", 16)
	bright_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.97, 1))
	box.add_child(bright_label)

	var bright_slider := HSlider.new()
	bright_slider.min_value = 0
	bright_slider.max_value = 100
	bright_slider.value = brightness
	bright_slider.custom_minimum_size = Vector2(220, 20)
	bright_slider.value_changed.connect(set_brightness)
	box.add_child(bright_slider)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)

	var back_btn := _make_menu_button("뒤로")
	back_btn.pressed.connect(_show_pause_main)
	box.add_child(back_btn)

	return box


func _make_menu_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 40)
	btn.flat = true
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.4, 1))
	btn.add_theme_font_size_override("font_size", 22)
	return btn


func _on_pause_main_menu_pressed() -> void:
	goto_scene("res://scenes/Title.tscn")


func _on_pause_quit_pressed() -> void:
	get_tree().quit()
