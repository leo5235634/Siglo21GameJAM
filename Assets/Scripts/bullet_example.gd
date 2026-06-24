extends CharacterBody2D


var Direction: Vector2 = Vector2.RIGHT
@export var speedBullet: float = 400.0
@export var damageAmount: float = 1.0
var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL

func _physics_process(delta: float) -> void:
	velocity = Direction.normalized() * speedBullet
	move_and_slide()

func launch(start_position: Vector2, target_position: Vector2, attack_damage: float) -> void:
	global_position = start_position
	Direction = start_position.direction_to(target_position).normalized()
	damageAmount = attack_damage
	rotation = Direction.angle()

func launch_direction(start_position: Vector2, direction: Vector2, attack_damage: float, attack_damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
	global_position = start_position
	Direction = direction.normalized()
	damageAmount = attack_damage
	damage_type = attack_damage_type
	rotation = Direction.angle()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy"):
		if body.has_method("TakeDamage"):
			body.TakeDamage(damageAmount, damage_type)
		queue_free()


func _on_timer_timeout() -> void:
	queue_free()
