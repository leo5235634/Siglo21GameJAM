extends Node2D
class_name AxeOrbitEffect

const WRENCH_TEXTURE: Texture2D = preload("res://Assets/Images/llave.png")
const WRENCH_DRAW_SIZE: Vector2 = Vector2(30.0, 60.0)

var player: Player
var damage_amount: float = 1.0
var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL
var axe_count: int = 1
var radius: float = 112.0
var duration: float = 0.75
var rotation_speed: float = TAU * 2.4
var elapsed: float = 0.0
var hit_enemies: Dictionary = {}

func setup(_owner: Player, _damage_amount: float, _axe_count: int) -> void:
	player = _owner
	damage_amount = _damage_amount
	axe_count = maxi(1, _axe_count)
	if player != null:
		global_position = player.global_position

func _process(delta: float) -> void:
	elapsed += delta
	if player == null or not is_instance_valid(player) or elapsed >= duration:
		queue_free()
		return
	global_position = player.global_position
	rotation += rotation_speed * delta
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var targeting_area: Area2D = player.get_node_or_null("Area2D") as Area2D
	if targeting_area == null:
		return
	for body in targeting_area.get_overlapping_bodies():
		var enemy: Enemy = body as Enemy
		if enemy == null or hit_enemies.has(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= radius + 24.0:
			hit_enemies[enemy] = true
			enemy.TakeDamage(damage_amount, damage_type)

func _draw() -> void:
	var alpha: float = 1.0 - clampf(elapsed / duration, 0.0, 1.0)
	for index in range(axe_count):
		var angle: float = TAU * float(index) / float(axe_count)
		var center: Vector2 = Vector2.RIGHT.rotated(angle) * radius
		draw_line(Vector2.ZERO, center, Color(0.65, 0.85, 0.95, 0.25 * alpha), 2.0)
		draw_set_transform(center, angle + PI * 0.5)
		draw_texture_rect(
			WRENCH_TEXTURE,
			Rect2(-WRENCH_DRAW_SIZE * 0.5, WRENCH_DRAW_SIZE),
			false,
			Color(1.0, 1.0, 1.0, alpha)
		)
		draw_set_transform(Vector2.ZERO, 0.0)
