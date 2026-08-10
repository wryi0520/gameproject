extends Node2D

const LIFETIME = 5.0
const SPEED = 140.0
const FOLLOW_DISTANCE = 26.0
const DETECTION_RADIUS = 110.0
const ATTACK_RANGE = 18.0
const ATTACK_COOLDOWN = 0.6
const ATTACK_DAMAGE = 1

var owner_player: Node2D = null
var follow_offset := Vector2.ZERO
var target_enemy: Node = null
var attack_cooldown_timer := 0.0
var life_timer := LIFETIME
var dissolving := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var dissolve_particles: CPUParticles2D = $DissolveParticles


func setup(player: Node2D, offset: Vector2) -> void:
	owner_player = player
	follow_offset = offset
	sprite.sprite_frames = player.get_node("AnimatedSprite2D").sprite_frames
	sprite.play("idle")


func _ready() -> void:
	sprite.modulate = Color(0.05, 0.05, 0.12, 0.85)
	lifetime_timer.wait_time = LIFETIME
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_start_dissolve)
	lifetime_timer.start()


func _process(delta: float) -> void:
	if dissolving or owner_player == null or not is_instance_valid(owner_player):
		return

	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)
	_update_target()

	var move_target: Vector2
	if target_enemy and is_instance_valid(target_enemy):
		move_target = target_enemy.global_position
	else:
		move_target = owner_player.global_position + follow_offset

	var to_target = move_target - global_position
	var distance = to_target.length()

	if target_enemy and distance <= ATTACK_RANGE:
		sprite.play("attack")
		if attack_cooldown_timer <= 0.0:
			attack_cooldown_timer = ATTACK_COOLDOWN
			if target_enemy.has_method("take_damage"):
				target_enemy.take_damage(ATTACK_DAMAGE)
	elif distance > 2.0:
		var dir = to_target.normalized()
		global_position += dir * SPEED * delta
		sprite.flip_h = dir.x < 0
		sprite.play("run")
	else:
		sprite.play("idle")


func _update_target() -> void:
	if target_enemy and is_instance_valid(target_enemy):
		if global_position.distance_to(target_enemy.global_position) <= DETECTION_RADIUS:
			return
		target_enemy = null

	var closest: Node = null
	var closest_dist := DETECTION_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d = global_position.distance_to(enemy.global_position)
		if d <= closest_dist:
			closest_dist = d
			closest = enemy
	target_enemy = closest


func _start_dissolve() -> void:
	if dissolving:
		return
	dissolving = true
	dissolve_particles.restart()
	dissolve_particles.emitting = true

	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(sprite, "scale", sprite.scale * 0.4, 0.35)
	tween.parallel().tween_property(sprite, "position", sprite.position + Vector2(0, -12), 0.35)
	tween.tween_interval(0.2)
	tween.tween_callback(queue_free)
