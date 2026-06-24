extends Weapon
class_name LaserWeapon

@export var targeting_area_path: NodePath = NodePath("../Area2D")
@export var beam_count: int = 1
@export var piercing: bool = false
@export var beam_width: float = 20.0
@export var base_damage_multiplier: float = 0.85
@export var damage_type: Stats.DamageType = Stats.DamageType.ELECTRIC
@export var visual_color: Color = Color(0.25, 0.9, 1.0, 0.9)
@export var idle_rotation_step_degrees: float = 71.0

var shot_sequence: int = 0

func _ready() -> void:
	weapon_id = "laser"
	display_name = "Bobina de rayos"
	use_player_fire_rate = false
	cooldown_seconds = 1.0

func try_attack(owner: Player, stats: Stats) -> bool:
	var muzzle_position: Vector2 = owner.get_weapon_muzzle_position(weapon_id)
	var target: Enemy = _find_nearest_enemy(owner, stats)
	var base_direction: Vector2 = _get_base_direction(owner, target)
	var spread_radians: float = deg_to_rad(18.0)
	var first_offset: float = -spread_radians * float(beam_count - 1) * 0.5
	for index in range(beam_count):
		_fire_beam(owner, stats, muzzle_position, base_direction.rotated(first_offset + spread_radians * float(index)))
	shot_sequence += 1
	return true

func _find_nearest_enemy(owner: Player, stats: Stats) -> Enemy:
	var enemies: Array[Enemy] = _find_nearest_enemies(owner, stats, 1)
	if enemies.is_empty():
		return null
	return enemies[0]

func apply_upgrade(upgrade_stat: Stats.BuffableStats) -> void:
	match upgrade_stat:
		Stats.BuffableStats.LASER_EXTRA_BEAM:
			beam_count = 2
		Stats.BuffableStats.LASER_PIERCING:
			piercing = true
		Stats.BuffableStats.LASER_DAMAGE:
			damage_multiplier += 0.25

func _find_nearest_enemies(owner: Player, stats: Stats, amount: int) -> Array[Enemy]:
	var targeting_area: Area2D = get_node_or_null(targeting_area_path) as Area2D
	if targeting_area == null:
		return []
	var found_enemies: Array[Enemy] = []
	var max_distance_squared: float = pow(stats.current_weapon_range * range_multiplier, 2.0)
	for body in targeting_area.get_overlapping_bodies():
		var enemy: Enemy = body as Enemy
		if enemy == null:
			continue
		var distance: float = owner.global_position.distance_squared_to(enemy.global_position)
		if distance <= max_distance_squared:
			_insert_enemy_by_distance(found_enemies, enemy, owner.global_position, amount)
	return found_enemies

func _insert_enemy_by_distance(enemies: Array[Enemy], enemy: Enemy, origin: Vector2, max_amount: int) -> void:
	var enemy_distance: float = origin.distance_squared_to(enemy.global_position)
	var insert_index: int = enemies.size()
	for index in range(enemies.size()):
		var other_distance: float = origin.distance_squared_to(enemies[index].global_position)
		if enemy_distance < other_distance:
			insert_index = index
			break
	enemies.insert(insert_index, enemy)
	if enemies.size() > max_amount:
		enemies.pop_back()

func _get_base_direction(owner: Player, target: Enemy) -> Vector2:
	if target != null:
		return owner.global_position.direction_to(target.global_position).normalized()
	if owner.velocity.length_squared() > 0.01:
		return owner.velocity.normalized().rotated(PI * 0.5)
	return Vector2.RIGHT.rotated(deg_to_rad(idle_rotation_step_degrees * float(shot_sequence) + 23.0))

func _fire_beam(owner: Player, stats: Stats, start_position: Vector2, direction: Vector2) -> void:
	direction = direction.normalized()
	if direction == Vector2.ZERO:
		return
	var max_distance: float = stats.current_weapon_range * range_multiplier
	var end_position: Vector2 = start_position + direction * max_distance
	var hit_enemies: Array[Enemy] = _get_hit_enemies(owner, stats, start_position, end_position)
	if not hit_enemies.is_empty() and not piercing:
		end_position = hit_enemies[0].global_position
		var first_enemy: Enemy = hit_enemies[0]
		hit_enemies.clear()
		hit_enemies.append(first_enemy)
	var damage_amount: float = stats.current_attack * base_damage_multiplier * damage_multiplier
	for enemy in hit_enemies:
		enemy.TakeDamage(damage_amount, damage_type)
	_spawn_effect(owner, start_position, end_position)

func _get_hit_enemies(owner: Player, stats: Stats, start_position: Vector2, end_position: Vector2) -> Array[Enemy]:
	var targeting_area: Area2D = get_node_or_null(targeting_area_path) as Area2D
	if targeting_area == null:
		return []
	var hit_enemies: Array[Enemy] = []
	var max_distance_squared: float = pow(stats.current_weapon_range * range_multiplier, 2.0)
	for body in targeting_area.get_overlapping_bodies():
		var enemy: Enemy = body as Enemy
		if enemy == null:
			continue
		if owner.global_position.distance_squared_to(enemy.global_position) > max_distance_squared:
			continue
		if _distance_to_segment(enemy.global_position, start_position, end_position) <= beam_width:
			_insert_enemy_by_distance(hit_enemies, enemy, start_position, 999)
	return hit_enemies

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment: Vector2 = segment_end - segment_start
	var length_squared: float = segment.length_squared()
	if is_zero_approx(length_squared):
		return point.distance_to(segment_start)
	var t: float = clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	var projection: Vector2 = segment_start + segment * t
	return point.distance_to(projection)

func _spawn_effect(owner: Player, start_position: Vector2, end_position: Vector2) -> void:
	var parent: Node = owner.get_parent()
	if parent == null:
		return
	var effect: LaserBeamEffect = LaserBeamEffect.new()
	effect.beam_width = beam_width * 0.5
	parent.add_child(effect)
	effect.setup(start_position, end_position, visual_color)
