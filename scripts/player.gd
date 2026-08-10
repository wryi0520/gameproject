extends CharacterBody2D

const SPEED = 120.0
const JUMP_VELOCITY = -380.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.18
const DASH_COOLDOWN = 0.6
const ATTACK_DURATION = 0.25
const ATTACK_DAMAGE = 1
const MAX_HEALTH = 5
const INVINCIBILITY_DURATION = 0.8

const WEAPON_REST_ROTATION = 2.0944  # 120 degrees, hanging at the side
const WEAPON_SWING_START = -0.6      # raised back, ~ -34 degrees
const WEAPON_SWING_END = 2.7         # forward slash, ~ 155 degrees

const ATTACK_LUNGE_SPEED = 150.0
const ATTACK_LUNGE_DECAY = 700.0

const MIRROR_HEALTH = 1

const SKILL_COOLDOWN = 10.0
const ALLY_COUNT = 2
const ALLY_SCENE: PackedScene = preload("res://scenes/Ally.tscn")

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

var facing := 1
var weapon_base_x: float
var sprite_base_scale := Vector2.ONE
var motion_time := 0.0

var in_mirror_world := false
var health_before_mirror := 0

var skill_cooldown_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hurtbox: Area2D = $Hurtbox
@onready var slash_effect: Sprite2D = $SlashEffect
@onready var mirror_sparkles: CPUParticles2D = $MirrorSparkles
@onready var summon_effect: Sprite2D = $SummonEffect


func _ready() -> void:
	add_to_group("player")
	hurtbox.add_to_group("player_hurtbox")
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	weapon_base_x = abs(weapon_pivot.position.x)
	weapon_pivot.rotation = WEAPON_REST_ROTATION
	sprite_base_scale = sprite.scale


func _physics_process(delta: float) -> void:
	motion_time += delta
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)
	skill_cooldown_timer = max(skill_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("interact"):
		_toggle_mirror_world()

	if Input.is_action_just_pressed("skill_q") and skill_cooldown_timer <= 0.0:
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
	attack_timer = ATTACK_DURATION
	attack_hitbox.position.x = abs(attack_hitbox.position.x) * facing
	attack_hitbox.monitoring = true
	attack_lunge_velocity = facing * ATTACK_LUNGE_SPEED

	_play_slash_effect()


func _process_attack(delta: float) -> void:
	attack_timer -= delta
	velocity.x = attack_lunge_velocity
	attack_lunge_velocity = move_toward(attack_lunge_velocity, 0.0, ATTACK_LUNGE_DECAY * delta)
	if attack_timer <= 0.0:
		is_attacking = false
		attack_hitbox.monitoring = false


func _play_slash_effect() -> void:
	slash_effect.position = Vector2(10, -6) * Vector2(facing, 1)
	slash_effect.scale = Vector2(0.15, 0.15) * Vector2(facing, 1)
	slash_effect.rotation = deg_to_rad(-20) * facing
	slash_effect.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(slash_effect, "scale", Vector2(1.0, 1.0) * Vector2(facing, 1), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_effect, "rotation", deg_to_rad(20) * facing, 0.1)
	tween.tween_property(slash_effect, "modulate:a", 0.0, ATTACK_DURATION * 0.6)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(ATTACK_DAMAGE)


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
	if is_invincible:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		died.emit()
		queue_free()
		return
	is_invincible = true
	invincible_timer = INVINCIBILITY_DURATION


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
