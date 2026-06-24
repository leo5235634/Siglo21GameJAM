extends Enemy
class_name BabyAllien

var canAttack: bool = false

func _ready() -> void:
	super._ready()


func _physics_process(delta: float) -> void:
	
	if Global.Player == null or not is_instance_valid(Global.Player): return
	
	if canAttack:
		Attack()
	else:
		Move()

func Move():
	var Direction: Vector2 = global_position.direction_to(Global.Player.global_position)
	velocity= Direction.normalized() * speed
	move_and_slide()
	
func Attack():
	if $Timer.time_left > 0: return
	Global.Player.TakeDamage(damage, damage_type)
	$Timer.start()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		canAttack = true
	
func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		canAttack = false
