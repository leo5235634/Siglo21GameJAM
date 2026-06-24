extends Enemy
class_name DroneEnemy

@export var arrival_distance: float = 18.0
@export var contact_damage_cooldown: float = 0.6

var destination: Vector2 = Vector2.ZERO
var has_destination: bool = false
var damaged_bodies: Dictionary = {}

func setup_route(start_position: Vector2, end_position: Vector2) -> void:
	global_position = start_position
	destination = end_position
	has_destination = true

func _physics_process(_delta: float) -> void:
	if not has_destination:
		return
	var direction: Vector2 = global_position.direction_to(destination)
	if global_position.distance_to(destination) <= arrival_distance:
		queue_free()
		return
	velocity = direction * speed
	move_and_slide()

func _on_hit_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player") or damaged_bodies.has(body):
		return
	damaged_bodies[body] = true
	if body.has_method("TakeDamage"):
		body.TakeDamage(damage, damage_type, defense_penetration)
	get_tree().create_timer(contact_damage_cooldown).timeout.connect(_clear_damaged_body.bind(body))

func _clear_damaged_body(body: Node2D) -> void:
	damaged_bodies.erase(body)
