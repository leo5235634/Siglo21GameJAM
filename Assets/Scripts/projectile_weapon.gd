extends Weapon
class_name ProjectileWeapon

@export var bullet_scene: PackedScene = preload("res://Scenes/bullet_example.tscn")
@export var targeting_area_path: NodePath = NodePath("../Area2D")
@export var visual_path: NodePath = NodePath("DoubleBarrelShotgunIcon")
@export var spread_degrees: float = 8.0
@export var extra_projectiles: int = 0
@export var idle_rotation_step_degrees: float = 47.0

var shot_sequence: int = 0

func try_attack(owner: Player, stats: Stats) -> bool:
	var target: Enemy = _find_nearest_enemy(owner, stats)
	var base_direction: Vector2 = _get_base_direction(owner, target)
	_aim_in_direction(base_direction)
	_fire_projectiles(owner, stats, base_direction)
	shot_sequence += 1
	return true

func _find_nearest_enemy(owner: Player, stats: Stats) -> Enemy:
	var targeting_area: Area2D = get_node_or_null(targeting_area_path) as Area2D
	if targeting_area == null:
		return null
	var nearest_enemy: Enemy = null
	var nearest_distance: float = INF
	var max_distance_squared: float = pow(stats.current_weapon_range * range_multiplier, 2.0)
	for body in targeting_area.get_overlapping_bodies():
		var enemy: Enemy = body as Enemy
		if enemy == null:
			continue
		var distance: float = owner.global_position.distance_squared_to(enemy.global_position)
		if distance <= max_distance_squared and distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	return nearest_enemy

func _aim_at(target_position: Vector2) -> void:
	var visual: Node2D = get_node_or_null(visual_path) as Node2D
	if visual != null:
		visual.look_at(target_position)

func _aim_in_direction(direction: Vector2) -> void:
	var visual: Node2D = get_node_or_null(visual_path) as Node2D
	if visual != null:
		visual.rotation = direction.angle()

func _get_base_direction(owner: Player, target: Enemy) -> Vector2:
	if target != null:
		return owner.global_position.direction_to(target.global_position).normalized()
	if owner.velocity.length_squared() > 0.01:
		return owner.velocity.normalized()
	return Vector2.RIGHT.rotated(deg_to_rad(idle_rotation_step_degrees * float(shot_sequence)))

func _fire_projectiles(owner: Player, stats: Stats, base_direction: Vector2) -> void:
	var parent: Node = owner.get_parent()
	if parent == null:
		return
	var muzzle_position: Vector2 = owner.get_weapon_muzzle_position(weapon_id)
	var projectile_count: int = maxi(1, roundi(stats.current_projectile_count) + extra_projectiles)
	var spread_radians: float = deg_to_rad(spread_degrees)
	var first_offset: float = -spread_radians * float(projectile_count - 1) * 0.5
	for index in range(projectile_count):
		var direction: Vector2 = base_direction.rotated(first_offset + spread_radians * float(index))
		var projectile: Node = bullet_scene.instantiate()
		parent.add_child(projectile)
		if projectile.has_method("launch_direction"):
			projectile.call("launch_direction", muzzle_position, direction, stats.current_attack * damage_multiplier, Stats.DamageType.PHYSICAL)
		elif projectile.has_method("launch"):
			projectile.call("launch", muzzle_position, muzzle_position + direction, stats.current_attack * damage_multiplier)
