extends Enemy
class_name MiniBossEnemy

@export var special_attack_cooldown: float = 4.0
@export var special_attack_range: float = 120.0
@export var special_attack_damage_multiplier: float = 2.0

var special_cooldown_left: float = 0.0

func _physics_process(delta: float) -> void:
	if special_cooldown_left > 0.0:
		special_cooldown_left -= delta

func can_use_special_attack() -> bool:
	if Global.Player == null or not is_instance_valid(Global.Player) or special_cooldown_left > 0.0:
		return false
	return global_position.distance_to(Global.Player.global_position) <= special_attack_range

func use_special_attack() -> void:
	if not can_use_special_attack():
		return
	Global.Player.TakeDamage(roundi(float(damage) * special_attack_damage_multiplier), damage_type)
	special_cooldown_left = special_attack_cooldown
	Global.debug_log("%s uso ataque especial" % name)
