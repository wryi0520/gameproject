extends GutTest

var player_scene := preload("res://scenes/Player.tscn")
var player: CharacterBody2D


func before_each() -> void:
	player = player_scene.instantiate()
	add_child_autofree(player)


func test_starts_with_max_health() -> void:
	assert_eq(player.health, player.MAX_HEALTH)


func test_take_damage_reduces_health() -> void:
	player.take_damage(1)
	assert_eq(player.health, player.MAX_HEALTH - 1)


func test_take_damage_grants_invincibility() -> void:
	player.take_damage(1)
	assert_true(player.is_invincible)


func test_take_damage_ignored_while_invincible() -> void:
	player.take_damage(1)
	var health_after_first_hit: int = player.health
	player.take_damage(1)
	assert_eq(player.health, health_after_first_hit)
