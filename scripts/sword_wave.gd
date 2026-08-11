extends Area2D

var velocity_x := 0.0
var damage := 2
var lifetime := 0.6

var _timer := 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	position.x += velocity_x * delta
	_timer += delta
	var t: float = clamp(_timer / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - t
	scale = Vector2.ONE * lerp(1.0, 0.45, t)
	if _timer >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_hurtbox"):
		return
	var enemy = area.get_parent()
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
	queue_free()
