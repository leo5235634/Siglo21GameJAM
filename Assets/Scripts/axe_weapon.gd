extends Weapon
class_name AxeWeapon

@export var axe_count: int = 1
@export var radius: float = 112.0
@export var effect_duration: float = 0.75
@export var base_damage_multiplier: float = 0.9

func _ready() -> void:
	weapon_id = "axe"
	display_name = "Llave orbital"
	use_player_fire_rate = false
	cooldown_seconds = 2.6

func try_attack(owner: Player, stats: Stats) -> bool:
	var parent: Node = owner.get_parent()
	if parent == null:
		return false
	var effect: AxeOrbitEffect = AxeOrbitEffect.new()
	effect.radius = radius
	effect.duration = effect_duration
	parent.add_child(effect)
	effect.setup(owner, stats.current_attack * base_damage_multiplier * damage_multiplier, axe_count)
	return true

func apply_upgrade(upgrade_stat: Stats.BuffableStats) -> void:
	match upgrade_stat:
		Stats.BuffableStats.AXE_COOLDOWN:
			cooldown_seconds = 1.2
		Stats.BuffableStats.AXE_EXTRA_AXE:
			axe_count += 1
		Stats.BuffableStats.AXE_DAMAGE:
			damage_multiplier += 0.25
