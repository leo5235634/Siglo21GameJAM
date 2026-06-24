extends CharacterBody2D
class_name Enemy

@export var speed: float = 200.0
@export var max_health: float = 3.0
@export var experience_value: float = 25.0
@export var gem_scene: PackedScene = preload("res://Scenes/Gema.tscn")
@export_range(0.0, 1.0, 0.01) var drop_gem_chance: float = 1.0
@export var damage: int = 1
@export var damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL
@export_range(0.0, 1.0, 0.01) var defense_penetration: float = 0.0
@export var stats: Stats
@export var phase_health_ratios: Array[float] = []
@export var damage_flash_duration: float = 0.08
@export var damage_flash_color: Color = Color.WHITE

var health: float
var current_phase: int = 0
var is_dead: bool = false
var damage_flash_sprite: CanvasItem
var damage_flash_original_material: Material
var damage_flash_tween: Tween

signal phase_changed(new_phase: int)
signal died(enemy: Enemy)

func _ready() -> void:
	add_to_group("Enemy")
	damage_flash_sprite = _find_damage_flash_sprite(self)
	if damage_flash_sprite != null:
		damage_flash_original_material = damage_flash_sprite.material
	if stats != null:
		if not stats.health_depleted.is_connected(_die):
			stats.health_depleted.connect(_die)
		stats.base_max_health = max_health
		stats.setup_stats()
		health = stats.health
	else:
		health = max_health

func TakeDamage(damage_amount: float, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL) -> void:
	if is_dead:
		return
	if stats != null:
		stats.take_damage(damage_amount, damage_type)
		health = stats.health
	else:
		health -= damage_amount
	_update_phase()
	#Global.debug_log("%s vida: %s / %s" % [name, health, _get_max_health()])
	if health <= 0.0 and stats == null:
		_die()
	elif health > 0.0 and not is_dead:
		_play_damage_flash()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	Global.register_enemy_kill()
	_drop_gem()
	died.emit(self)
	queue_free()

func _drop_gem() -> void:
	if gem_scene == null or randf() > drop_gem_chance:
		return
	var gem: Node2D = gem_scene.instantiate() as Node2D
	if gem == null:
		return
	if gem.has_method("set_experience_amount"):
		gem.set_experience_amount(experience_value)
	var parent: Node = get_parent()
	if parent == null:
		return
	gem.global_position = global_position
	parent.call_deferred("add_child", gem)

func _get_max_health() -> float:
	if stats != null:
		return stats.current_max_health
	return max_health

func _update_phase() -> void:
	if phase_health_ratios.is_empty():
		return
	var health_ratio: float = health / maxf(_get_max_health(), 1.0)
	var next_phase: int = current_phase
	for index in range(phase_health_ratios.size()):
		if health_ratio <= phase_health_ratios[index]:
			next_phase = index + 1
	if next_phase != current_phase:
		current_phase = next_phase
		phase_changed.emit(current_phase)
		_on_phase_changed(current_phase)

func _on_phase_changed(new_phase: int) -> void:
	Global.debug_log("%s entro en fase %s" % [name, new_phase])

func _play_damage_flash() -> void:
	if damage_flash_sprite == null or damage_flash_duration <= 0.0:
		return
	if damage_flash_tween != null:
		damage_flash_tween.kill()
	var flash_material: ShaderMaterial = ShaderMaterial.new()
	flash_material.shader = _get_damage_flash_shader()
	flash_material.set_shader_parameter("flash_color", damage_flash_color)
	damage_flash_sprite.material = flash_material
	damage_flash_tween = create_tween()
	damage_flash_tween.tween_interval(damage_flash_duration)
	damage_flash_tween.tween_callback(_restore_damage_flash_material)

func _restore_damage_flash_material() -> void:
	if damage_flash_sprite == null or not is_instance_valid(damage_flash_sprite):
		return
	damage_flash_sprite.material = damage_flash_original_material

func _find_damage_flash_sprite(node: Node) -> CanvasItem:
	if node is Sprite2D:
		return node as CanvasItem
	for child in node.get_children():
		var found_sprite: CanvasItem = _find_damage_flash_sprite(child)
		if found_sprite != null:
			return found_sprite
	return null

func _get_damage_flash_shader() -> Shader:
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 sampled = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(flash_color.rgb, sampled.a * flash_color.a);
}
"""
	return shader
