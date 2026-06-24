extends Resource

class_name Stats

enum BuffableStats {
	MAX_HEALTH,
	DEFENSE,
	ATTACK,
	MOVE_SPEED,
	FIRE_RATE,
	DAMAGE_REDUCTION,
	PHYSICAL_RESISTANCE,
	ELECTRIC_RESISTANCE,
	FIRE_RESISTANCE,
	SHIELD,
	PICKUP_RANGE,
	PROJECTILE_COUNT,
	WEAPON_RANGE,
	SHOTGUN_WEAPON,
	SHOTGUN_EXTRA_PROJECTILE,
	SHOTGUN_FIRE_RATE,
	SHOTGUN_DAMAGE,
	LASER_WEAPON,
	LASER_EXTRA_BEAM,
	LASER_PIERCING,
	LASER_DAMAGE,
	AXE_WEAPON,
	AXE_COOLDOWN,
	AXE_EXTRA_AXE,
	AXE_DAMAGE,
	HEALTH_REGEN
}

enum DamageType {
	PHYSICAL,
	ELECTRIC,
	FIRE
}

const STAT_CURVES: Dictionary[BuffableStats, Curve] = {
	BuffableStats.MAX_HEALTH: preload("uid://divtg5lq3xjxq"),
	BuffableStats.DEFENSE: preload("uid://c27gscam2eo3x"),
	BuffableStats.ATTACK: preload("uid://cv71swhfj6rm3")
}

const BASE_LEVEL_EXP: float = 100.0
const DEFENSE_REDUCTION_SCALE: float = 300.0
const MAX_DEFENSE_REDUCTION: float = 0.65
const MAX_NATURAL_HEALTH: float = 150.0
const MAX_DEFENSE: float = 100.0
const MAX_ATTACK_WITHOUT_UPGRADE: float = 200.0

signal health_depleted
signal health_changed(cur_health: float , max_health:float)
signal damage_taken(raw_damage: float, final_damage: float, damage_type: DamageType)
signal damage_blocked(raw_damage: float, damage_type: DamageType)
signal experience_changed(experience: float, level: int)
signal stats_changed
signal leveled_up(new_level: int, old_level: int)

@export var base_max_health: float = 100
@export var base_defense: float = 10
@export var base_attack: float = 10
@export var base_move_speed: float = 300
@export var base_fire_rate: float = 5
@export_range(0.0, 0.95, 0.01) var base_damage_reduction: float = 0.0
@export_range(0.0, 0.95, 0.01) var base_physical_resistance: float = 0.0
@export_range(0.0, 0.95, 0.01) var base_electric_resistance: float = 0.0
@export_range(0.0, 0.95, 0.01) var base_fire_resistance: float = 0.0
@export var base_pickup_range: float = 120
@export var base_projectile_count: float = 1
@export var base_weapon_range: float = 256
@export var base_health_regen: float = 0.0
@export var experience: float = 0: set = on_experience_set

var level: int:
	get(): return int(floor(max(1.0,sqrt(experience / BASE_LEVEL_EXP) + 0.5)))
	
var current_max_health: float = 100
var current_defense: float = 10
var current_attack: float = 10
var current_move_speed: float = 300
var current_fire_rate: float = 5
var current_damage_reduction: float = 0
var current_physical_resistance: float = 0
var current_electric_resistance: float = 0
var current_fire_resistance: float = 0
var current_pickup_range: float = 120
var current_projectile_count: float = 1
var current_weapon_range: float = 256
var current_health_regen: float = 0.0
var health: float = 0 : set = _on_health_set
var is_invulnerable: bool = false

var stat_buffs: Array[StatBuff]

func _init() -> void:
	setup_stats.call_deferred()
	
func setup_stats() -> void:
	var previous_max_health: float = current_max_health
	var previous_health: float = health
	recalculate_stats()
	if previous_health <= 0.0:
		health = current_max_health
	else:
		var health_ratio: float = previous_health / previous_max_health
		health = current_max_health * health_ratio
	stats_changed.emit()

func add_buff(buff: StatBuff, heal_to_max: bool = false) ->void:
	stat_buffs.append(buff)
	_recalculate_stats_and_refresh_health(heal_to_max)
	
func remove_buff(buff: StatBuff) ->void:
	stat_buffs.erase(buff)
	_recalculate_stats_and_refresh_health(false)

func _recalculate_stats_and_refresh_health(heal_to_max: bool = false) -> void:
	recalculate_stats()
	if heal_to_max:
		health = current_max_health
	else:
		health = health
	stats_changed.emit()
	
func recalculate_stats() -> void:
	var stat_multipliers: Dictionary = {}
	var stat_addens: Dictionary = {}
	var has_attack_upgrade: bool = false
	#recorre los diccionarios de mejoras y le indica como comportarse
	for buff in stat_buffs:
		var stat_name: String = BuffableStats.keys()[buff.stat].to_lower()
		if buff.stat == BuffableStats.ATTACK:
			has_attack_upgrade = true
		match  buff.buff_type:
			StatBuff.BuffType.ADD:
				if not stat_addens.has(stat_name):
					stat_addens[stat_name] = 0.0
				stat_addens[stat_name] += buff.buff_amount
			StatBuff.BuffType.MULTIPLY:
				if not stat_multipliers.has(stat_name):
					stat_multipliers[stat_name] = 1.0
				stat_multipliers[stat_name] += buff.buff_amount
				
				if stat_multipliers[stat_name] < 0.0:
					stat_multipliers[stat_name] = 0.0
	#stats actuales
	var stat_sample_pos: float = (float(level) / 100.0) -0.01
	current_max_health = base_max_health * _get_curve_multiplier(BuffableStats.MAX_HEALTH, stat_sample_pos)
	current_defense = base_defense * _get_curve_multiplier(BuffableStats.DEFENSE, stat_sample_pos)
	current_attack = base_attack * _get_curve_multiplier(BuffableStats.ATTACK, stat_sample_pos)
	current_max_health = minf(current_max_health, MAX_NATURAL_HEALTH)
	current_attack = minf(current_attack, MAX_ATTACK_WITHOUT_UPGRADE)
	current_move_speed = base_move_speed * _get_curve_multiplier(BuffableStats.MOVE_SPEED, stat_sample_pos)
	current_fire_rate = base_fire_rate * _get_curve_multiplier(BuffableStats.FIRE_RATE, stat_sample_pos)
	current_damage_reduction = base_damage_reduction
	current_physical_resistance = base_physical_resistance
	current_electric_resistance = base_electric_resistance
	current_fire_resistance = base_fire_resistance
	current_pickup_range = base_pickup_range
	current_projectile_count = base_projectile_count
	current_weapon_range = base_weapon_range
	current_health_regen = base_health_regen
	
	#aplica mejoras de nivel por multiplicador
	for stat_name in stat_multipliers:
		var cur_property_name: String = str("current_" + stat_name)
		var multiplier_current_value: Variant = get(cur_property_name)
		if multiplier_current_value == null:
			Global.debug_log("Stats ignoro buff sin propiedad actual: %s" % cur_property_name)
			continue
		set(cur_property_name, float(multiplier_current_value) * stat_multipliers[stat_name])
	
	#aplica mejoras de nivel por incremento
	for stat_name in stat_addens:
		var cur_property_name: String = str("current_" + stat_name)
		var add_current_value: Variant = get(cur_property_name)
		if add_current_value == null:
			Global.debug_log("Stats ignoro buff sin propiedad actual: %s" % cur_property_name)
			continue
		set(cur_property_name, float(add_current_value) + stat_addens[stat_name])

	current_defense = minf(current_defense, MAX_DEFENSE)
	if not has_attack_upgrade:
		current_attack = minf(current_attack, MAX_ATTACK_WITHOUT_UPGRADE)

func _on_health_set(new_value: float) -> void:
	health = clampf(new_value,0,current_max_health)
	health_changed.emit(health,current_max_health)
	if health <= 0:
		health_depleted.emit()

func take_damage(raw_damage: float, damage_type: DamageType = DamageType.PHYSICAL, defense_penetration: float = 0.0) -> float:
	if is_invulnerable:
		damage_blocked.emit(raw_damage, damage_type)
		return 0.0
	var final_damage: float = get_damage_after_defense(raw_damage, damage_type, defense_penetration)
	health -= final_damage
	damage_taken.emit(raw_damage, final_damage, damage_type)
	return final_damage

func get_damage_after_defense(raw_damage: float, damage_type: DamageType = DamageType.PHYSICAL, defense_penetration: float = 0.0) -> float:
	if raw_damage <= 0.0:
		return 0.0
	var percent_reduction: float = clampf(current_damage_reduction + _get_resistance_for_damage_type(damage_type), 0.0, 0.95)
	var effective_defense: float = current_defense * (1.0 - clampf(defense_penetration, 0.0, 1.0))
	var defense_reduction: float = _get_defense_reduction(effective_defense)
	return maxf(raw_damage * (1.0 - percent_reduction) * (1.0 - defense_reduction), 1.0)

func _get_defense_reduction(defense: float) -> float:
	if defense <= 0.0:
		return 0.0
	return clampf(defense / (defense + DEFENSE_REDUCTION_SCALE), 0.0, MAX_DEFENSE_REDUCTION)

func set_invulnerable(value: bool) -> void:
	is_invulnerable = value

func _get_resistance_for_damage_type(damage_type: DamageType) -> float:
	match damage_type:
		DamageType.PHYSICAL:
			return current_physical_resistance
		DamageType.ELECTRIC:
			return current_electric_resistance
		DamageType.FIRE:
			return current_fire_resistance
	return 0.0

func _get_curve_multiplier(stat: BuffableStats, sample_pos: float) -> float:
	if not STAT_CURVES.has(stat):
		return 1.0
	var level_one_sample_pos: float = (1.0 / 100.0) - 0.01
	var level_one_value: float = STAT_CURVES[stat].sample(level_one_sample_pos)
	if is_zero_approx(level_one_value):
		return 1.0
	return STAT_CURVES[stat].sample(sample_pos) / level_one_value

func add_experience(amount: float) -> void:
	experience += maxf(amount, 0.0)

func get_experience_for_level(target_level: int) -> float:
	var normalized_level: float = float(max(target_level, 1)) - 0.5
	return normalized_level * normalized_level * BASE_LEVEL_EXP

func get_experience_for_level_start(target_level: int) -> float:
	if target_level <= 1:
		return 0.0
	return get_experience_for_level(target_level)

func get_current_level_experience() -> float:
	return maxf(experience - get_experience_for_level_start(level), 0.0)

func get_next_level_required_experience() -> float:
	var current_level_start: float = get_experience_for_level_start(level)
	var next_level_start: float = get_experience_for_level(level + 1)
	return maxf(next_level_start - current_level_start, 1.0)

func get_level_progress_ratio() -> float:
	return clampf(get_current_level_experience() / get_next_level_required_experience(), 0.0, 1.0)

func get_experience_to_next_level() -> float:
	return maxf(get_experience_for_level(level + 1) - experience, 0.0)

func on_experience_set(new_value:float ) ->void:
	var old_level: int = level
	experience = maxf(new_value, 0.0)
	
	if not old_level == level:
		recalculate_stats()
		health = current_max_health
		stats_changed.emit()
		leveled_up.emit(level, old_level)
	experience_changed.emit(experience, level)
