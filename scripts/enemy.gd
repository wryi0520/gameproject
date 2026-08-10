extends CharacterBody2D

const SPEED = 40.0
const CHASE_SPEED = 70.0
const MAX_HEALTH = 3
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 1.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var attack_damage := ATTACK_DAMAGE

var health := MAX_HEALTH
var direction := -1
var player: Node2D = null
var attack_cooldown_timer := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_area: Area2D = $AttackArea
@onready var detection_area: Area2D = $DetectionArea
@onready var patrol_timer: Timer = $PatrolTimer


func _ready() -> void:
	hurtbox.add_to_group("enemy_hurtbox")
	add_to_group("enemy")

	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	patrol_timer.timeout.connect(_on_patrol_timer_timeout)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	attack_cooldown_timer = max(attack_cooldown_timer - delta, 0.0)

	if player:
		var to_player = player.global_position.x - global_position.x
		direction = 1 if to_player > 0 else -1
		velocity.x = direction * CHASE_SPEED
	else:
		velocity.x = direction * SPEED

	sprite.flip_h = direction < 0
	move_and_slide()
	_update_animation()
	_try_attack()


func _try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return
	for area in attack_area.get_overlapping_areas():
		if area.is_in_group("player_hurtbox"):
			var target = area.get_parent()
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
				attack_cooldown_timer = ATTACK_COOLDOWN
			break


func _update_animation() -> void:
	if abs(velocity.x) > 1.0:
		sprite.play("run")
	else:
		sprite.play("idle")


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null


func _on_patrol_timer_timeout() -> void:
	if not player:
		direction *= -1


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
		return
	sprite.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.15).timeout
	sprite.modulate = Color(1, 1, 1)
