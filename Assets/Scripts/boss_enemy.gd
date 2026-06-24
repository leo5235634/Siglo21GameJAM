extends Enemy
class_name BossEnemy

@export var damage_per_phase_multiplier: float = 0.25
@export var speed_per_phase_multiplier: float = 0.15

var base_boss_damage: int
var base_boss_speed: float

func _ready() -> void:
	base_boss_damage = damage
	base_boss_speed = speed
	if phase_health_ratios.is_empty():
		phase_health_ratios = [0.66, 0.33]
	super._ready()

func _on_phase_changed(new_phase: int) -> void:
	damage = maxi(1, roundi(float(base_boss_damage) * (1.0 + damage_per_phase_multiplier * float(new_phase))))
	speed = base_boss_speed * (1.0 + speed_per_phase_multiplier * float(new_phase))
	Global.debug_log("%s fase %s: dano %s, velocidad %s" % [name, new_phase, damage, speed])
