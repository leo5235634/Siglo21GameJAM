extends Area2D

@export var experience_amount: float = 25.0
@export var attraction_speed: float = 360.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if Global.Player == null or not is_instance_valid(Global.Player) or Global.Player.stats == null:
		return
	var distance: float = global_position.distance_to(Global.Player.global_position)
	if distance > Global.Player.stats.current_pickup_range:
		return
	global_position = global_position.move_toward(Global.Player.global_position, attraction_speed * delta)

func set_experience_amount(amount: float) -> void:
	experience_amount = maxf(amount, 0.0)

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("add_experience"):
		return
	body.add_experience(experience_amount)
	queue_free()
