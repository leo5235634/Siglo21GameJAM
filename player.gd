extends CharacterBody2D


@export var speed: float = 10  
@export var stats: Stats

func _ready() -> void:
	Global.Player = self
	
	
func _physics_process(delta: float) -> void:
	
	var Direction := Input.get_vector("izquierda","derecha","arriba","abajo")
	
	velocity = Direction * speed
	
	move_and_slide()
