extends Control

const PIP_GAP = 4.0
const PIP_WIDTH = 30.0
const PIP_HEIGHT = 22.0
const MARGIN = 20.0

const NORMAL_COLOR = Color(0.8, 0.16, 0.16)
const MIRROR_COLOR = Color(0.2, 0.45, 0.9)
const EMPTY_COLOR = Color(0.12, 0.06, 0.06, 0.9)
const FRAME_COLOR = Color(0.05, 0.03, 0.03, 0.95)

const SKILL_SLOT_SIZE = 40.0
const SKILL_GAP = 10.0
const SKILL_MARGIN = 20.0
const READY_COLOR = Color(1, 1, 1, 1)
const COOLDOWN_COLOR = Color(0.32, 0.32, 0.35, 1)

var player: Node = null
var _current_health := 0
var _max_health := 5
var _mirror_active := false

@onready var background: ColorRect = $Background
@onready var fill: ColorRect = $Fill
@onready var label: Label = $Label

var _pip_root: Control
var _pips: Array = []
var _flash_rect: ColorRect
var _glow_rect: ColorRect
var _pulse_tween: Tween
var _hp_label: Label

var _skill_root: Control
var _q_icon: TextureRect
var _q_cooldown_label: Label
var _e_icon: TextureRect
var _e_cooldown_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	background.visible = false
	fill.visible = false
	label.visible = false

	_build_health_ui()
	_build_skill_ui()

	call_deferred("_connect_to_player")
	call_deferred("_layout")


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.skills_locked:
		_lock_skill_slot(_q_icon, _q_cooldown_label)
		_lock_skill_slot(_e_icon, _e_cooldown_label)
		return
	_update_skill_slot(_q_icon, _q_cooldown_label, player.skill_cooldown_timer, player.SKILL_COOLDOWN)
	_update_skill_slot(_e_icon, _e_cooldown_label, player.mirror_cooldown_timer, player.MIRROR_COOLDOWN)


func _layout() -> void:
	var vp_size = get_viewport_rect().size
	var row_width = _max_health * PIP_WIDTH + (_max_health - 1) * PIP_GAP
	_pip_root.position = Vector2(vp_size.x - row_width - MARGIN, vp_size.y - PIP_HEIGHT - MARGIN)
	_skill_root.position = Vector2(SKILL_MARGIN, vp_size.y - SKILL_SLOT_SIZE - SKILL_MARGIN)


func _connect_to_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	player = players[0]
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	player.mirror_world_changed.connect(_on_mirror_world_changed)
	_on_health_changed(player.health, player.MAX_HEALTH)


# ---------------- Health pips ----------------

func _build_health_ui() -> void:
	_pip_root = Control.new()
	_pip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pip_root)

	_glow_rect = ColorRect.new()
	_glow_rect.color = Color(1, 0, 0, 0)
	_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_root.add_child(_glow_rect)

	_hp_label = Label.new()
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_root.add_child(_hp_label)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pip_root.add_child(_flash_rect)

	_rebuild_pips()


func _rebuild_pips() -> void:
	for entry in _pips:
		entry["frame"].queue_free()
		entry["pip"].queue_free()
	_pips.clear()

	for i in range(_max_health):
		var frame := ColorRect.new()
		frame.color = FRAME_COLOR
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pip_root.add_child(frame)

		var pip := ColorRect.new()
		pip.color = NORMAL_COLOR
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pip_root.add_child(pip)

		_pips.append({"frame": frame, "pip": pip})

	_pip_root.move_child(_glow_rect, 0)
	_pip_root.move_child(_flash_rect, _pip_root.get_child_count() - 1)
	_position_pips()


func _position_pips() -> void:
	var glow_pad := 6.0
	var row_width = _max_health * PIP_WIDTH + (_max_health - 1) * PIP_GAP
	_glow_rect.position = Vector2(-glow_pad, -glow_pad)
	_glow_rect.size = Vector2(row_width + glow_pad * 2.0, PIP_HEIGHT + glow_pad * 2.0)

	for i in range(_pips.size()):
		var x := i * (PIP_WIDTH + PIP_GAP)
		var frame: ColorRect = _pips[i]["frame"]
		var pip: ColorRect = _pips[i]["pip"]
		frame.position = Vector2(x, 0)
		frame.size = Vector2(PIP_WIDTH, PIP_HEIGHT)
		pip.position = Vector2(x + 2, 2)
		pip.size = Vector2(PIP_WIDTH - 4, PIP_HEIGHT - 4)

	_flash_rect.position = Vector2(0, 0)
	_flash_rect.size = Vector2(row_width, PIP_HEIGHT)

	_hp_label.position = Vector2(0, -15)
	_hp_label.size = Vector2(row_width, 14)


func _on_health_changed(current: int, max_health: int) -> void:
	if max_health != _max_health:
		_max_health = max_health
		_rebuild_pips()
		_layout()

	var damaged := current < _current_health
	_current_health = current

	var active_color := MIRROR_COLOR if _mirror_active else NORMAL_COLOR
	for i in range(_pips.size()):
		var pip: ColorRect = _pips[i]["pip"]
		pip.color = active_color if i < current else EMPTY_COLOR

	_hp_label.text = "%d / %d" % [current, max_health]

	if damaged:
		_play_damage_effect()

	_update_low_health_pulse()


func _play_damage_effect() -> void:
	_flash_rect.color = Color(1, 1, 1, 0.85)
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.25)

	var base_pos: Vector2 = _pip_root.position
	var shake_tween := create_tween()
	shake_tween.tween_property(_pip_root, "position", base_pos + Vector2(-4, 0), 0.03)
	shake_tween.tween_property(_pip_root, "position", base_pos + Vector2(4, 0), 0.05)
	shake_tween.tween_property(_pip_root, "position", base_pos + Vector2(-2, 0), 0.05)
	shake_tween.tween_property(_pip_root, "position", base_pos, 0.05)


func _update_low_health_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	if _current_health == 1:
		_glow_rect.color = Color(1, 0, 0, 0)
		_pulse_tween = create_tween()
		_pulse_tween.set_loops()
		_pulse_tween.tween_property(_glow_rect, "color:a", 0.55, 0.4).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(_glow_rect, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		_glow_rect.color.a = 0.0


func _on_mirror_world_changed(active: bool) -> void:
	_mirror_active = active
	var active_color := MIRROR_COLOR if active else NORMAL_COLOR
	for i in range(_pips.size()):
		var pip: ColorRect = _pips[i]["pip"]
		if i < _current_health:
			pip.color = active_color


func _on_player_died() -> void:
	_on_health_changed(0, _max_health)


# ---------------- Skill icons ----------------

func _build_skill_ui() -> void:
	_skill_root = Control.new()
	_skill_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_root)

	var q_data := _make_skill_slot("Q", "summon")
	_q_icon = q_data["icon"]
	_q_cooldown_label = q_data["label"]

	var e_data := _make_skill_slot("E", "mirror")
	e_data["frame"].position = Vector2(SKILL_SLOT_SIZE + SKILL_GAP, 0)
	_e_icon = e_data["icon"]
	_e_cooldown_label = e_data["label"]


func _make_skill_slot(key_text: String, icon_kind: String) -> Dictionary:
	var frame := ColorRect.new()
	frame.color = FRAME_COLOR
	frame.size = Vector2(SKILL_SLOT_SIZE, SKILL_SLOT_SIZE)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_root.add_child(frame)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.12, 0.06, 0.06, 0.9)
	backdrop.position = Vector2(2, 2)
	backdrop.size = Vector2(SKILL_SLOT_SIZE - 4, SKILL_SLOT_SIZE - 4)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(backdrop)

	var icon := TextureRect.new()
	icon.texture = _make_icon_texture(icon_kind)
	icon.position = Vector2(6, 6)
	icon.size = Vector2(SKILL_SLOT_SIZE - 12, SKILL_SLOT_SIZE - 12)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var key_label := Label.new()
	key_label.text = key_text
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	key_label.position = Vector2(2, -2)
	key_label.size = Vector2(16, 14)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(key_label)

	var cooldown_label := Label.new()
	cooldown_label.text = ""
	cooldown_label.add_theme_font_size_override("font_size", 18)
	cooldown_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	cooldown_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	cooldown_label.add_theme_constant_override("outline_size", 3)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cooldown_label)

	return {"frame": frame, "icon": icon, "label": cooldown_label}


func _update_skill_slot(icon: TextureRect, cooldown_label: Label, timer: float, total: float) -> void:
	if total <= 0.0:
		return
	var ratio: float = clamp(timer / total, 0.0, 1.0)
	icon.modulate = COOLDOWN_COLOR.lerp(READY_COLOR, 1.0 - ratio)
	if timer > 0.05:
		cooldown_label.text = str(int(ceil(timer)))
	else:
		cooldown_label.text = ""


func _lock_skill_slot(icon: TextureRect, cooldown_label: Label) -> void:
	icon.modulate = Color(0.32, 0.32, 0.35, 0.5)
	cooldown_label.text = ""


func _make_icon_texture(kind: String) -> ImageTexture:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)

	if kind == "summon":
		var head_center := Vector2(center.x, center.y - 5.0)
		var body_center := Vector2(center.x, center.y + 4.0)
		for x in range(size):
			for y in range(size):
				var p := Vector2(x, y)
				if p.distance_to(head_center) < 4.0 or p.distance_to(body_center) < 6.5:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
	elif kind == "mirror":
		for x in range(size):
			for y in range(size):
				var d: float = abs(x - center.x) + abs(y - center.y)
				if d < 9.0:
					img.set_pixel(x, y, Color(1, 1, 1, 1))
				elif d < 10.5:
					img.set_pixel(x, y, Color(1, 1, 1, 0.5))

	return ImageTexture.create_from_image(img)
