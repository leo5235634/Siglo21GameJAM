extends Node2D
class_name Weapon

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var damage_multiplier: float = 1.0
@export var fire_rate_multiplier: float = 1.0
@export var range_multiplier: float = 1.0
@export var use_player_fire_rate: bool = true
@export var cooldown_seconds: float = 1.0

var cooldown: float = 0.0

func tick(delta: float, owner: Player, stats: Stats) -> void:
	if cooldown > 0.0:
		cooldown -= delta
		return
	if try_attack(owner, stats):
		cooldown = _get_cooldown_seconds(stats)

func try_attack(owner: Player, stats: Stats) -> bool:
	return false

func apply_upgrade(_upgrade_stat: Stats.BuffableStats) -> void:
	pass

func _get_cooldown_seconds(stats: Stats) -> float:
	if use_player_fire_rate:
		var shots_per_second: float = maxf(stats.current_fire_rate * fire_rate_multiplier, 0.1)
		return 1.0 / shots_per_second
	return maxf(cooldown_seconds, 0.05)
