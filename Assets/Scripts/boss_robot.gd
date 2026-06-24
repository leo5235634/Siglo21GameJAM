extends Enemy
class_name BossRobot

var can_attack: bool = false

func _ready() -> void:
	super._ready()

func _physics_process(_delta: float) -> void:
	if Global.Player == null or not is_instance_valid(Global.Player):
		return
	if can_attack:
		_attack()
	else:
		_move()

func _move() -> void:
	var direction: Vector2 = global_position.direction_to(Global.Player.global_position)
	velocity = direction.normalized() * speed
	move_and_slide()

func _attack() -> void:
	if $AttackTimer.time_left > 0:
		return
	Global.Player.TakeDamage(damage, damage_type, defense_penetration)
	$AttackTimer.start()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		can_attack = true

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		can_attack = false
