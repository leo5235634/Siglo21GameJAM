extends Node2D

@export var enemigo: PackedScene = preload("res://Scenes/enemigo1.tscn")
@export var boss_scene: PackedScene = preload("res://Scenes/BossRobot.tscn")
@export var drone_scene: PackedScene = preload("res://Scenes/DroneEnemy.tscn")
@export var sphere_miniboss_scene: PackedScene = preload("res://Scenes/SphereMiniBoss.tscn")
@export var base_wait_time: float = 1.2
@export var min_wait_time: float = 0.2
@export var wait_time_decrease_per_minute: float = 0.25
@export var extra_enemy_per_minute: int = 1
@export var enemy_health_growth_per_minute: float = 0.25
@export var enemy_damage_growth_per_minute: float = 0.15
@export var spawn_outside_camera: bool = true
@export var boss_spawn_interval_seconds: float = 300.0
@export var boss_kills_required_to_win: int = 1
@export_file("*.tscn") var victory_scene_path: String = "res://Scenes/VictoryMenu.tscn"
@export var drone_wave_interval_seconds: float = 30.0
@export var drone_wave_count: int = 4
@export var drone_wave_spacing: float = 48.0
@export var drone_spawn_margin: float = 120.0
@export var drone_health_growth_per_minute: float = 0.2
@export var drone_damage_growth_per_minute: float = 0.1
@export var sphere_miniboss_first_spawn_seconds: float = 60.0
@export var sphere_miniboss_interval_seconds: float = 40.0
@export var sphere_miniboss_health_growth_per_minute: float = 0.35
@export var sphere_miniboss_damage_growth_per_minute: float = 0.18

@onready var timer: Timer = get_parent().get_node_or_null("Timer") as Timer

var next_boss_spawn_time: float = 300.0
var next_drone_wave_time: float = 30.0
var next_sphere_miniboss_time: float = 60.0
var active_boss: Enemy
var defeated_boss_count: int = 0
var victory_triggered: bool = false

func _ready() -> void:
	next_boss_spawn_time = boss_spawn_interval_seconds
	next_drone_wave_time = drone_wave_interval_seconds
	next_sphere_miniboss_time = sphere_miniboss_first_spawn_seconds
	if timer != null:
		timer.wait_time = base_wait_time

func _process(_delta: float) -> void:
	if victory_triggered or not Global.is_run_active:
		return
	if Global.survived_time >= next_drone_wave_time:
		_spawn_drone_wave()
		next_drone_wave_time = _get_next_drone_wave_time()
	if Global.survived_time >= next_sphere_miniboss_time:
		_spawn_sphere_miniboss()
		next_sphere_miniboss_time = _get_next_sphere_miniboss_time()

func _on_timer_timeout() -> void:
	if victory_triggered:
		return
	if _has_active_boss():
		return
	if Global.survived_time >= next_boss_spawn_time:
		_spawn_boss()
		return
	var minutes: float = Global.survived_time / 60.0
	var amount: int = 1 + int(floor(minutes * float(extra_enemy_per_minute)))
	for index in range(amount):
		_spawn_enemy(minutes)
	_update_timer(minutes)

func _spawn_enemy(minutes: float) -> void:
	var enemy: Node2D = enemigo.instantiate() as Node2D
	if enemy == null:
		return
	if enemy is Enemy:
		var typed_enemy: Enemy = enemy as Enemy
		typed_enemy.max_health *= 1.0 + minutes * enemy_health_growth_per_minute
		typed_enemy.damage = maxi(1, roundi(float(typed_enemy.damage) * (1.0 + minutes * enemy_damage_growth_per_minute)))
		typed_enemy.experience_value *= 1.0 + minutes * 0.1
	add_child(enemy)
	enemy.global_position = _get_spawn_position()

func _spawn_drone_wave() -> void:
	if drone_scene == null:
		return
	var route: Array[Vector2] = _get_drone_route()
	if route.size() < 2:
		return
	var start_position: Vector2 = route[0]
	var end_position: Vector2 = route[1]
	var direction: Vector2 = start_position.direction_to(end_position).normalized()
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var minutes: float = Global.survived_time / 60.0
	var first_offset: float = -drone_wave_spacing * float(drone_wave_count - 1) * 0.5
	for index in range(drone_wave_count):
		var drone: DroneEnemy = drone_scene.instantiate() as DroneEnemy
		if drone == null:
			continue
		var offset: Vector2 = perpendicular * (first_offset + drone_wave_spacing * float(index))
		drone.max_health *= 1.0 + minutes * drone_health_growth_per_minute
		drone.damage = maxi(1, roundi(float(drone.damage) * (1.0 + minutes * drone_damage_growth_per_minute)))
		drone.experience_value *= 1.0 + minutes * 0.1
		add_child(drone)
		drone.setup_route(start_position + offset, end_position + offset)
	Global.debug_log("Oleada de drones en %s segundos" % Global.survived_time)

func _spawn_sphere_miniboss() -> void:
	if sphere_miniboss_scene == null:
		return
	var sphere: Enemy = sphere_miniboss_scene.instantiate() as Enemy
	if sphere == null:
		return
	var minutes: float = Global.survived_time / 60.0
	sphere.max_health *= 1.0 + minutes * sphere_miniboss_health_growth_per_minute
	sphere.damage = maxi(1, roundi(float(sphere.damage) * (1.0 + minutes * sphere_miniboss_damage_growth_per_minute)))
	sphere.experience_value *= 1.0 + minutes * 0.1
	add_child(sphere)
	sphere.global_position = _get_spawn_position_outside_camera()
	Global.debug_log("Miniboss esfera spawneado en %s segundos" % Global.survived_time)

func _spawn_boss() -> void:
	if boss_scene == null:
		next_boss_spawn_time += boss_spawn_interval_seconds
		return
	var boss: Enemy = boss_scene.instantiate() as Enemy
	if boss == null:
		next_boss_spawn_time += boss_spawn_interval_seconds
		return
	active_boss = boss
	add_child(boss)
	boss.global_position = _get_spawn_position()
	if not boss.died.is_connected(_on_boss_died):
		boss.died.connect(_on_boss_died)
	Global.debug_log("Boss spawneado en %s segundos" % Global.survived_time)

func _on_boss_died(_boss: Enemy) -> void:
	active_boss = null
	defeated_boss_count += 1
	if _should_trigger_victory():
		_trigger_victory()
		return
	next_boss_spawn_time = _get_next_boss_spawn_time()
	Global.debug_log("Boss derrotado. Proximo boss en %s segundos" % next_boss_spawn_time)

func _has_active_boss() -> bool:
	return active_boss != null and is_instance_valid(active_boss)

func _should_trigger_victory() -> bool:
	return boss_kills_required_to_win > 0 and defeated_boss_count >= boss_kills_required_to_win

func _trigger_victory() -> void:
	if victory_triggered:
		return
	victory_triggered = true
	var player_stats: Stats = null
	if Global.Player != null and is_instance_valid(Global.Player):
		player_stats = Global.Player.stats
		if Global.Player.has_method("shake_camera"):
			Global.Player.call("shake_camera", 10.0, 0.35)
	Global.finish_run("victory", player_stats)
	if timer != null:
		timer.stop()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", victory_scene_path)

func _get_next_boss_spawn_time() -> float:
	var next_time: float = next_boss_spawn_time + boss_spawn_interval_seconds
	while next_time <= Global.survived_time:
		next_time += boss_spawn_interval_seconds
	return next_time

func _get_next_drone_wave_time() -> float:
	var next_time: float = next_drone_wave_time + drone_wave_interval_seconds
	while next_time <= Global.survived_time:
		next_time += drone_wave_interval_seconds
	return next_time

func _get_next_sphere_miniboss_time() -> float:
	var next_time: float = next_sphere_miniboss_time + sphere_miniboss_interval_seconds
	while next_time <= Global.survived_time:
		next_time += sphere_miniboss_interval_seconds
	return next_time

func _update_timer(minutes: float) -> void:
	if timer == null:
		return
	timer.wait_time = maxf(min_wait_time, base_wait_time - minutes * wait_time_decrease_per_minute)

func _get_spawn_position() -> Vector2:
	if spawn_outside_camera and Global.Player != null and is_instance_valid(Global.Player):
		return _get_spawn_position_outside_camera()
	return Vector2(
		randf_range($x1.global_position.x, $x2.global_position.x),
		randf_range($y1.global_position.y, $y2.global_position.y)
	)

func _get_spawn_position_outside_camera() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = Global.Player.global_position
	if camera != null:
		center = camera.global_position
	var margin: float = 80.0
	var half_size: Vector2 = viewport_size * 0.5
	var side: int = randi_range(0, 3)
	match side:
		0:
			return center + Vector2(randf_range(-half_size.x, half_size.x), -half_size.y - margin)
		1:
			return center + Vector2(randf_range(-half_size.x, half_size.x), half_size.y + margin)
		2:
			return center + Vector2(-half_size.x - margin, randf_range(-half_size.y, half_size.y))
	return center + Vector2(half_size.x + margin, randf_range(-half_size.y, half_size.y))

func _get_drone_route() -> Array[Vector2]:
	var corners: Array[Vector2] = _get_drone_corners()
	var start_index: int = randi_range(0, corners.size() - 1)
	var end_index: int = 3 - start_index
	return [corners[start_index], corners[end_index]]

func _get_drone_corners() -> Array[Vector2]:
	var viewport_size: Vector2 = get_viewport_rect().size
	var camera: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = Vector2(
		($x1.global_position.x + $x2.global_position.x) * 0.5,
		($y1.global_position.y + $y2.global_position.y) * 0.5
	)
	if camera != null:
		center = camera.global_position
	elif Global.Player != null and is_instance_valid(Global.Player):
		center = Global.Player.global_position
	var half_size: Vector2 = viewport_size * 0.5
	return [
		center + Vector2(-half_size.x - drone_spawn_margin, -half_size.y - drone_spawn_margin),
		center + Vector2(half_size.x + drone_spawn_margin, -half_size.y - drone_spawn_margin),
		center + Vector2(-half_size.x - drone_spawn_margin, half_size.y + drone_spawn_margin),
		center + Vector2(half_size.x + drone_spawn_margin, half_size.y + drone_spawn_margin),
	]
