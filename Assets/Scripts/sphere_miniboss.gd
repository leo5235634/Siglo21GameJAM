extends Enemy
class_name SphereMiniBoss

@export var preferred_distance: float = 420.0
@export var distance_tolerance: float = 70.0
@export var strafe_speed_multiplier: float = 0.45
@export var laser_range: float = 760.0
@export var laser_width: float = 24.0
@export var laser_warning_time: float = 1.0
@export var laser_active_time: float = 0.22
@export var laser_cooldown: float = 4.0
@export var laser_damage: int = 35

var laser_cooldown_left: float = 1.0
var warning_left: float = 0.0
var active_laser_left: float = 0.0
var locked_start: Vector2 = Vector2.ZERO
var locked_end: Vector2 = Vector2.ZERO
var did_laser_damage: bool = false

@onready var warning_line: Line2D = $WarningLine
@onready var laser_line: Line2D = $LaserLine

func _ready() -> void:
	super._ready()
	warning_line.width = laser_width * 0.35
	warning_line.visible = false
	laser_line.width = laser_width
	laser_line.visible = false

func _physics_process(delta: float) -> void:
	if Global.Player == null or not is_instance_valid(Global.Player):
		return
	_tick_laser(delta)
	if warning_left > 0.0 or active_laser_left > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_move_around_player(delta)
	if laser_cooldown_left <= 0.0 and global_position.distance_to(Global.Player.global_position) <= laser_range:
		_start_laser_warning()

func _tick_laser(delta: float) -> void:
	if laser_cooldown_left > 0.0:
		laser_cooldown_left -= delta
	if warning_left > 0.0:
		warning_left -= delta
		_update_line(warning_line)
		if warning_left <= 0.0:
			_fire_laser()
	elif active_laser_left > 0.0:
		active_laser_left -= delta
		_update_line(laser_line)
		if not did_laser_damage:
			_damage_player_on_line()
			did_laser_damage = true
		if active_laser_left <= 0.0:
			laser_line.visible = false

func _move_around_player(delta: float) -> void:
	var to_player: Vector2 = global_position.direction_to(Global.Player.global_position)
	var distance: float = global_position.distance_to(Global.Player.global_position)
	var movement: Vector2 = Vector2.ZERO
	if distance > preferred_distance + distance_tolerance:
		movement += to_player
	elif distance < preferred_distance - distance_tolerance:
		movement -= to_player
	var strafe_direction: float = 1.0 if int(Global.survived_time) % 2 == 0 else -1.0
	movement += Vector2(-to_player.y, to_player.x) * strafe_direction * strafe_speed_multiplier
	velocity = movement.normalized() * speed if movement.length_squared() > 0.01 else Vector2.ZERO
	move_and_slide()

func _start_laser_warning() -> void:
	var direction: Vector2 = global_position.direction_to(Global.Player.global_position).normalized()
	if direction == Vector2.ZERO:
		return
	locked_start = global_position
	locked_end = locked_start + direction * laser_range
	warning_left = laser_warning_time
	warning_line.visible = true
	laser_line.visible = false
	_update_line(warning_line)

func _fire_laser() -> void:
	warning_line.visible = false
	active_laser_left = laser_active_time
	did_laser_damage = false
	laser_cooldown_left = laser_cooldown
	laser_line.visible = true
	_update_line(laser_line)

func _update_line(line: Line2D) -> void:
	line.points = PackedVector2Array([Vector2.ZERO, locked_end - global_position])

func _damage_player_on_line() -> void:
	if Global.Player == null or not is_instance_valid(Global.Player):
		return
	if _distance_to_segment(Global.Player.global_position, locked_start, locked_end) <= laser_width:
		Global.Player.TakeDamage(laser_damage, Stats.DamageType.ELECTRIC, defense_penetration)

func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment: Vector2 = segment_end - segment_start
	var length_squared: float = segment.length_squared()
	if is_zero_approx(length_squared):
		return point.distance_to(segment_start)
	var t: float = clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * t)
