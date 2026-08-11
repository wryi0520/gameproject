extends CharacterBody2D

const SPEED = 120.0
const JUMP_VELOCITY = -380.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.6
const ATTACK_DAMAGE = 1
const MAX_HEALTH = 5

const COMBO_COUNT = 3
const COMBO_WINDOW = 0.6
const ATTACK_DURATIONS = [0.25, 0.22, 0.32]
const ATTACK_LUNGE_SPEEDS = [150.0, 220.0, 80.0]
const ATTACK_DAMAGES = [1, 1, 2]
const ATTACK_HITBOX_REACH = [12.0, 20.0, 16.0]

const SWORD_WAVE_SCENE_SCRIPT: GDScript = preload("res://scripts/sword_wave.gd")
const SWORD_WAVE_SPEED = 260.0
const SWORD_WAVE_LIFETIME = 0.6
const SWORD_WAVE_DAMAGE = 2
const INVINCIBILITY_DURATION = 0.8

const WEAPON_REST_ROTATION = 2.0944  # 120 degrees, hanging at the side
const WEAPON_SWING_START = -0.6      # raised back, ~ -34 degrees
const WEAPON_SWING_END = 2.7         # forward slash, ~ 155 degrees

const ATTACK_LUNGE_DECAY = 700.0

const MIRROR_HEALTH = 1

const FALL_LIMIT_Y = 760.0

const SKILL_COOLDOWN = 10.0
const ALLY_COUNT = 2
const ALLY_SCENE: PackedScene = preload("res://scenes/Ally.tscn")

const MIRROR_COOLDOWN = 1.2

const RUN_LEAN = 0.12       # radians, forward lean while running
const IDLE_BOB_AMPLITUDE = 1.0
const IDLE_BOB_SPEED = 2.5
const LEAN_SMOOTHING = 10.0

signal health_changed(current: int, max: int)
signal died
signal mirror_world_changed(active: bool)

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)

var health := MAX_HEALTH
var is_invincible := false
var invincible_timer := 0.0

var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := 1

var is_attacking := false
var attack_timer := 0.0
var attack_lunge_velocity := 0.0
var combo_index := 0
var combo_reset_timer := 0.0
var _current_attack_damage := ATTACK_DAMAGE

var facing := 1
var weapon_base_x: float
var sprite_base_scale := Vector2.ONE
var motion_time := 0.0

var in_mirror_world := false
var health_before_mirror := 0

var skill_cooldown_timer := 0.0
var mirror_cooldown_timer := 0.0
var is_transitioning := false
var skills_locked := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hurtbox: Area2D = $Hurtbox
@onready var slash_effect: Sprite2D = $SlashEffect
@onready var camera: Camera2D = $Camera2D
@onready var mirror_sparkles: CPUParticles2D = $MirrorSparkles
@onready var summon_effect: Sprite2D = $SummonEffect


func _ready() -> void:
	add_to_group("player")
	hurtbox.add_to_group("player_hurtbox")
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	weapon_base_x = abs(weapon_pivot.position.x)
	weapon_pivot.rotation = WEAPON_REST_ROTATION
	sprite_base_scale = sprite.scale

	var current_scene := get_tree().current_scene
	skills_locked = current_scene != null and current_scene.name == "Stage1"

	if GameState.has_pending_spawn:
		global_position = GameState.consume_spawn()
	var restored_health := GameState.consume_health()
	if restored_health > 0:
		health = restored_health
		health_changed.emit(health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	if is_transitioning:
		return

	if global_position.y > FALL_LIMIT_Y:
		_fall_off_map()
		return

	motion_time += delta
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	skill_cooldown_timer = max(skill_cooldown_timer - delta, 0.0)
	mirror_cooldown_timer = max(mirror_cooldown_timer - delta, 0.0)

	if combo_reset_timer > 0.0:
		combo_reset_timer = max(combo_reset_timer - delta, 0.0)
		if combo_reset_timer <= 0.0 and not is_attacking:
			combo_index = 0

	if not skills_locked and Input.is_action_just_pressed("interact") and mirror_cooldown_timer <= 0.0:
		_toggle_mirror_world()
		mirror_cooldown_timer = MIRROR_COOLDOWN

	if not skills_locked and Input.is_action_just_pressed("skill_q") and skill_cooldown_timer <= 0.0:
		_cast_summon_allies()

	if is_invincible:
		invincible_timer -= delta
		sprite.modulate.a = 0.5 if int(invincible_timer * 10) % 2 == 0 else 1.0
		if invincible_timer <= 0.0:
			is_invincible = false
			sprite.modulate.a = 1.0

	if is_dashing:
		_process_dash(delta)
	elif is_attacking:
		_process_attack(delta)
		if not is_on_floor():
			velocity.y += gravity * delta
	else:
		_process_movement(delta)

	move_and_slide()
	_update_animation()
	_update_weapon_facing()
	_update_body_motion(delta)


func _process_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing = 1 if direction > 0 else -1
		sprite.flip_h = facing < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		_start_dash()
	elif Input.is_action_just_pressed("attack"):
		_start_attack()


func _update_weapon_facing() -> void:
	weapon_pivot.position.x = weapon_base_x * facing
	weapon_pivot.scale.x = facing


func _update_body_motion(delta: float) -> void:
	var is_running: bool = is_on_floor() and not is_dashing and not is_attacking and abs(velocity.x) > 1.0
	var target_rotation: float = 0.0
	var target_offset_y: float = 0.0

	if is_running:
		target_rotation = RUN_LEAN * facing
	elif not is_dashing and not is_attacking and is_on_floor() and abs(velocity.x) <= 1.0:
		target_offset_y = sin(motion_time * IDLE_BOB_SPEED) * IDLE_BOB_AMPLITUDE

	sprite.rotation = lerp_angle(sprite.rotation, target_rotation, min(delta * LEAN_SMOOTHING, 1.0))
	sprite.position.y = lerp(sprite.position.y, target_offset_y, min(delta * LEAN_SMOOTHING, 1.0))


func _start_dash() -> void:
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_direction = facing
	velocity.y = 0


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.x = dash_direction * DASH_SPEED
	velocity.y = 0
	if dash_timer <= 0.0:
		is_dashing = false
		dash_cooldown_timer = DASH_COOLDOWN


func _start_attack() -> void:
	is_attacking = true
	var hit := combo_index

	attack_timer = ATTACK_DURATIONS[hit]
	attack_hitbox.position.x = ATTACK_HITBOX_REACH[hit] * facing
	attack_hitbox.monitoring = true
	attack_lunge_velocity = facing * ATTACK_LUNGE_SPEEDS[hit]
	_current_attack_damage = ATTACK_DAMAGES[hit]

	match hit:
		0:
			_play_slash_effect()
		1:
			_play_thrust_effect()
		2:
			_play_finisher_effect()

	_play_attack_body_motion(hit)

	combo_index = (combo_index + 1) % COMBO_COUNT
	combo_reset_timer = COMBO_WINDOW


func _play_attack_body_motion(hit: int) -> void:
	var punch_scale: Vector2
	var lean_deg: float
	var hop: float
	match hit:
		0:
			punch_scale = Vector2(1.14, 0.9)
			lean_deg = 16.0
			hop = -3.0
		1:
			punch_scale = Vector2(1.24, 0.85)
			lean_deg = 8.0
			hop = -1.0
		_:
			punch_scale = Vector2(1.32, 0.78)
			lean_deg = 26.0
			hop = -7.0

	var duration: float = ATTACK_DURATIONS[hit]
	var punch_time: float = min(0.06, duration * 0.35)

	sprite.scale = sprite_base_scale
	sprite.rotation = 0.0
	sprite.position.y = 0.0

	var scale_tween := create_tween()
	scale_tween.tween_property(sprite, "scale", sprite_base_scale * punch_scale, punch_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(sprite, "scale", sprite_base_scale, duration - punch_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var lean_tween := create_tween()
	lean_tween.tween_property(sprite, "rotation", deg_to_rad(lean_deg) * facing, punch_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lean_tween.tween_property(sprite, "rotation", 0.0, duration - punch_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var hop_tween := create_tween()
	hop_tween.tween_property(sprite, "position:y", hop, punch_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(sprite, "position:y", 0.0, duration - punch_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if hit == 2:
		_play_camera_shake()
		_play_hit_stop()


func _play_camera_shake() -> void:
	var shake_tween := create_tween()
	shake_tween.tween_property(camera, "offset", Vector2(-5, 3), 0.03)
	shake_tween.tween_property(camera, "offset", Vector2(5, -2), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2(-3, 1), 0.05)
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func _play_hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0


func _process_attack(delta: float) -> void:
	attack_timer -= delta
	velocity.x = attack_lunge_velocity
	attack_lunge_velocity = move_toward(attack_lunge_velocity, 0.0, ATTACK_LUNGE_DECAY * delta)
	if attack_timer <= 0.0:
		is_attacking = false
		attack_hitbox.monitoring = false


func _play_slash_effect() -> void:
	slash_effect.modulate = Color(1, 1, 1, 1)
	slash_effect.position = Vector2(10, -6) * Vector2(facing, 1)
	slash_effect.scale = Vector2(0.15, 0.15) * Vector2(facing, 1)
	slash_effect.rotation = deg_to_rad(-20) * facing
	slash_effect.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(slash_effect, "scale", Vector2(1.0, 1.0) * Vector2(facing, 1), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_effect, "rotation", deg_to_rad(20) * facing, 0.1)
	tween.tween_property(slash_effect, "modulate:a", 0.0, ATTACK_DURATIONS[0] * 0.6)


func _play_thrust_effect() -> void:
	slash_effect.modulate = Color(1, 1, 1, 1)
	slash_effect.position = Vector2(6, -2) * Vector2(facing, 1)
	slash_effect.scale = Vector2(0.05, 0.12) * Vector2(facing, 1)
	slash_effect.rotation = 0.0

	var tween = create_tween()
	tween.tween_property(slash_effect, "position", Vector2(28, -2) * Vector2(facing, 1), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_effect, "scale", Vector2(0.9, 0.12) * Vector2(facing, 1), 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash_effect, "modulate:a", 0.0, ATTACK_DURATIONS[1] * 0.5)


func _play_finisher_effect() -> void:
	slash_effect.modulate = Color(1.3, 1.3, 1.7, 1.0)
	slash_effect.position = Vector2(10, -6) * Vector2(facing, 1)
	slash_effect.scale = Vector2(0.2, 0.2) * Vector2(facing, 1)
	slash_effect.rotation = deg_to_rad(-30) * facing

	var tween = create_tween()
	tween.tween_property(slash_effect, "scale", Vector2(1.6, 1.6) * Vector2(facing, 1), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_effect, "rotation", deg_to_rad(30) * facing, 0.16)
	tween.tween_property(slash_effect, "modulate:a", 0.0, ATTACK_DURATIONS[2] * 0.35)

	_spawn_sword_wave()


func _spawn_sword_wave() -> void:
	var wave := Area2D.new()
	wave.set_script(SWORD_WAVE_SCENE_SCRIPT)
	wave.monitoring = true
	wave.monitorable = false
	wave.velocity_x = facing * SWORD_WAVE_SPEED
	wave.damage = SWORD_WAVE_DAMAGE
	wave.lifetime = SWORD_WAVE_LIFETIME

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 12)
	shape.shape = rect
	wave.add_child(shape)

	var wave_sprite := Sprite2D.new()
	wave_sprite.texture = slash_effect.texture
	wave_sprite.scale = Vector2(0.55, 0.3) * Vector2(facing, 1)
	wave_sprite.rotation = deg_to_rad(-10) * facing
	wave_sprite.modulate = Color(1.4, 1.4, 1.8, 1.0)
	wave.add_child(wave_sprite)

	get_parent().add_child(wave)
	wave.global_position = global_position + Vector2(18 * facing, -6)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(_current_attack_damage)


func _cast_summon_allies() -> void:
	skill_cooldown_timer = SKILL_COOLDOWN
	_play_summon_effect()

	var parent = get_parent()
	for i in range(ALLY_COUNT):
		var ally = ALLY_SCENE.instantiate()
		var angle = (TAU / ALLY_COUNT) * i
		var offset = Vector2(cos(angle), sin(angle)) * 20.0
		parent.add_child(ally)
		ally.global_position = global_position + offset
		ally.setup(self, offset)


func _play_summon_effect() -> void:
	summon_effect.scale = Vector2(0.4, 0.4)
	summon_effect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(summon_effect, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_property(summon_effect, "modulate:a", 0.0, 0.3)


func _toggle_mirror_world() -> void:
	in_mirror_world = not in_mirror_world

	if in_mirror_world:
		health_before_mirror = health
		health = MIRROR_HEALTH
	else:
		health = health_before_mirror

	health_changed.emit(health, MAX_HEALTH)
	mirror_world_changed.emit(in_mirror_world)
	_play_mirror_transition_effect()


func _play_mirror_transition_effect() -> void:
	mirror_sparkles.restart()
	mirror_sparkles.emitting = true

	var flash_color = Color(0.75, 0.85, 1.0) if in_mirror_world else Color(1.0, 1.0, 1.0)
	var punch_scale = sprite_base_scale * 1.35
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", flash_color * 2.5, 0.06)
	tween.parallel().tween_property(sprite, "scale", punch_scale, 0.06)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.22)
	tween.parallel().tween_property(sprite, "scale", sprite_base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func take_damage(amount: int) -> void:
	if is_invincible or is_transitioning:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()
		return
	is_invincible = true
	invincible_timer = INVINCIBILITY_DURATION


func _fall_off_map() -> void:
	is_transitioning = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	GameState.fall_into_depths(get_tree().current_scene.scene_file_path, health)


func _die() -> void:
	is_transitioning = true
	died.emit()
	velocity = Vector2.ZERO
	set_physics_process(false)
	GameState.die_into_death_realm(get_tree().current_scene.scene_file_path, global_position)


func _update_animation() -> void:
	sprite.speed_scale = 1.0
	if is_dashing:
		sprite.play("dash")
	elif is_attacking:
		sprite.play("attack")
	elif not is_on_floor():
		sprite.play("jump" if velocity.y < 0 else "fall")
	elif abs(velocity.x) > 1.0:
		sprite.play("run")
		sprite.speed_scale = clamp(abs(velocity.x) / SPEED, 0.4, 1.3)
	else:
		sprite.play("idle")
