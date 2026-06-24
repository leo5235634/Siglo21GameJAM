extends CharacterBody2D
class_name Player

@export var speed: float = 10  
@export var stats: Stats
@export var damage_camera_shake_duration: float = 0.16
@export var damage_camera_shake_strength: float = 5.0

signal upgrade_choices_ready(choices: Array[StatBuff])

const MAX_UPGRADE_STACKS_PER_STAT: int = 3
const MAX_ACTIVE_UPGRADE_STATS: int = 4
const MAX_WEAPON_SLOTS: int = 2
const WEAPON_SHOTGUN: String = "shotgun"
const WEAPON_LASER: String = "laser"
const WEAPON_AXE: String = "axe"

var pending_upgrade_choices: Array[StatBuff] = []
var pending_upgrade_levels: Array[int] = []
var upgrade_counts_by_stat: Dictionary[Stats.BuffableStats, int] = {}
var upgrade_menu_active: bool = false
var pause_menu_active: bool = false
var is_dead: bool = false

var bullet: PackedScene = preload("res://Scenes/bullet_example.tscn")
var upgrade_menu_scene: PackedScene = preload("res://Scenes/UpgradeMenu.tscn")
var pause_menu_scene: PackedScene = preload("res://Scenes/PauseMenu.tscn")
var hud_scene: PackedScene = preload("res://Scenes/HUD.tscn")
var character_textures: Array[Texture2D] = [
	preload("res://Assets/Images/ingeniero.png"),
	preload("res://Assets/Images/mecanico.png"),
	preload("res://Assets/Images/electricista.png"),
]
var hud: Node
var pause_menu: Node
var weapons: Array[Weapon] = []
var owned_weapon_ids: Dictionary[String, bool] = {}
var held_weapon_order: Array[String] = []
var shotgun_weapon: ShotgunWeapon
var laser_weapon: LaserWeapon
var axe_weapon: AxeWeapon
var shield_enabled: bool = false
var shield_ready: bool = false
var shield_cooldown_timer: float = 0.0
var invulnerability_timer: SceneTreeTimer
var camera_base_offset: Vector2 = Vector2.ZERO
var camera_shake_time_left: float = 0.0
var camera_shake_duration: float = 0.0
var camera_shake_strength: float = 0.0
var hit_flash_tween: Tween

@onready var health_bar: ProgressBar = $HealthBar
@onready var player_sprite: Sprite2D = $OneHanded
@onready var camera: Camera2D = $Camera2D
@onready var weapon_range_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var right_hand_anchor: Marker2D = $HandAnchors/RightHand
@onready var left_hand_anchor: Marker2D = $HandAnchors/LeftHand
@onready var electric_sphere: Sprite2D = $HandAnchors/ElectricSphere
@onready var electric_sphere_muzzle: Marker2D = $HandAnchors/ElectricSphere/Muzzle
@onready var shotgun_visual: Sprite2D = $Weapon/DoubleBarrelShotgunIcon
@onready var shotgun_muzzle: Marker2D = $Weapon/DoubleBarrelShotgunIcon/pivot

#texto de prueba para control de version
func _ready() -> void:
	Global.Player = self
	if camera != null:
		camera_base_offset = camera.offset
	if stats != null:
		if not stats.health_changed.is_connected(_on_stats_health_changed):
			stats.health_changed.connect(_on_stats_health_changed)
		if not stats.leveled_up.is_connected(_on_stats_leveled_up):
			stats.leveled_up.connect(_on_stats_leveled_up)
		if not stats.stats_changed.is_connected(_on_stats_changed):
			stats.stats_changed.connect(_on_stats_changed)
		stats.setup_stats()
		_update_health_bar(stats.health, stats.current_max_health)
		_update_fire_rate()
		_update_weapon_range()
		_apply_selected_character_sprite()
		_show_hud.call_deferred()
	_setup_starting_weapon()
	Global.start_run()

###Funcion de godot en la que se ejecutan las fisicas 
# - En este caso las direcciones estan mapeadas desde el proyecto:
# W = arriba , A= izquierda, D= derecha y S= abajo
# Luego multiplica la direccion por speed y nos da la velocidad hacia donde mover
###
func _physics_process(delta: float) -> void:
	
	var Direction := Input.get_vector("izquierda","derecha","arriba","abajo")
	
	velocity = Direction * _get_current_speed()
	
	move_and_slide()
	_tick_shield(delta)
	_tick_health_regen(delta)
	_tick_weapons(delta)
	_tick_camera_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_pause_input(event):
		return
	if upgrade_menu_active or is_dead:
		return
	if get_tree().paused and not pause_menu_active:
		return
	toggle_pause_menu()
	get_viewport().set_input_as_handled()

func Shot() -> void:
	_tick_weapons(999.0)
			
	
func add_experience(amount: float) -> void:
	if stats == null:
		return
	stats.add_experience(amount)
	Global.debug_log("Player EXP: %s | Nivel: %s | Falta: %s" % [stats.experience, stats.level, stats.get_experience_to_next_level()])

func choose_upgrade(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= pending_upgrade_choices.size():
		return
	var selected_buff: StatBuff = pending_upgrade_choices[choice_index]
	_register_upgrade_stack(selected_buff.stat)
	if _is_weapon_unlock(selected_buff.stat) or _is_weapon_upgrade(selected_buff.stat):
		_apply_weapon_upgrade(selected_buff.stat)
	elif selected_buff.stat == Stats.BuffableStats.SHIELD:
		_apply_shield_upgrade()
	else:
		var heal_to_max: bool = selected_buff.stat == Stats.BuffableStats.MAX_HEALTH
		stats.add_buff(selected_buff, heal_to_max)
	pending_upgrade_choices.clear()
	upgrade_menu_active = false
	_show_next_upgrade_menu.call_deferred()

func _on_stats_leveled_up(new_level: int, old_level: int) -> void:
	for level in range(old_level + 1, new_level + 1):
		pending_upgrade_levels.append(level)
	_show_next_upgrade_menu.call_deferred()
	Global.debug_log("Nivel %s alcanzado desde %s. Mejoras en cola: %s" % [new_level, old_level, pending_upgrade_levels.size()])

func _show_next_upgrade_menu() -> void:
	if upgrade_menu_active:
		return
	if pending_upgrade_levels.is_empty():
		get_tree().paused = false
		return
	var next_level: int = int(pending_upgrade_levels.pop_front())
	pending_upgrade_choices = _build_upgrade_choices(next_level)
	if pending_upgrade_choices.is_empty():
		Global.debug_log("No quedan mejoras disponibles para nivel %s" % next_level)
		_show_next_upgrade_menu.call_deferred()
		return
	upgrade_menu_active = true
	AudioManager.play_level_up()
	upgrade_choices_ready.emit(pending_upgrade_choices)
	var menu: Node = upgrade_menu_scene.instantiate()
	get_tree().root.add_child(menu)
	if menu.has_method("setup"):
		menu.call("setup", self, pending_upgrade_choices, next_level)
	Global.debug_log("Menu nivel %s. Mejoras disponibles: %s" % [next_level, _get_upgrade_choice_names(pending_upgrade_choices)])

func _show_hud() -> void:
	if hud != null and is_instance_valid(hud):
		return
	hud = hud_scene.instantiate()
	get_tree().root.add_child(hud)
	if hud.has_method("setup"):
		hud.call("setup", stats)

func _build_upgrade_choices(new_level: int) -> Array[StatBuff]:
	var amount_scale: float = 1.0 + (float(new_level) * 0.02)
	var upgrade_pool: Array[StatBuff] = []
	upgrade_pool.append_array(_build_character_upgrade_pool(amount_scale))
	upgrade_pool.append_array(_build_weapon_unlock_pool(new_level))
	upgrade_pool.append_array(_build_owned_weapon_upgrade_pool(new_level))
	var available_pool: Array[StatBuff] = []
	for buff in upgrade_pool:
		if buff.min_level <= new_level and _can_offer_upgrade(buff):
			available_pool.append(buff)
	var choices: Array[StatBuff] = []
	available_pool.shuffle()
	var choice_count: int = int(min(3, available_pool.size()))
	for index in range(choice_count):
		choices.append(available_pool[index])
	return choices

func _build_character_upgrade_pool(amount_scale: float) -> Array[StatBuff]:
	return [
		StatBuff.new(Stats.BuffableStats.MAX_HEALTH, 15.0 * amount_scale, StatBuff.BuffType.ADD, StatBuff.Rarity.COMMON, 1, "Caldera reforzada"),
		StatBuff.new(Stats.BuffableStats.MOVE_SPEED, 0.03, StatBuff.BuffType.MULTIPLY, StatBuff.Rarity.COMMON, 1, "Botas engrasadas"),
		StatBuff.new(Stats.BuffableStats.PICKUP_RANGE, 45.0, StatBuff.BuffType.ADD, StatBuff.Rarity.COMMON, 1, "Iman de chatarra"),
		StatBuff.new(Stats.BuffableStats.DAMAGE_REDUCTION, 0.05, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 2, "Blindaje de vapor"),
		StatBuff.new(Stats.BuffableStats.SHIELD, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 2, "Escudo de emergencia"),
		StatBuff.new(Stats.BuffableStats.HEALTH_REGEN, 0.5 * amount_scale, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 2, "Reparacion automatica"),
	]

func _build_weapon_unlock_pool(new_level: int) -> Array[StatBuff]:
	if new_level < 2 or weapons.size() >= MAX_WEAPON_SLOTS:
		return []
	return [
		StatBuff.new(Stats.BuffableStats.SHOTGUN_WEAPON, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.EPIC, 2, "Escopeta"),
		StatBuff.new(Stats.BuffableStats.LASER_WEAPON, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.EPIC, 2, "Bobina de rayos"),
		StatBuff.new(Stats.BuffableStats.AXE_WEAPON, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.EPIC, 2, "Llave orbital"),
	]

func _build_owned_weapon_upgrade_pool(_new_level: int) -> Array[StatBuff]:
	var weapon_pool: Array[StatBuff] = []
	if has_weapon(WEAPON_SHOTGUN):
		_add_next_weapon_upgrade(weapon_pool, WEAPON_SHOTGUN)
	if has_weapon(WEAPON_LASER):
		_add_next_weapon_upgrade(weapon_pool, WEAPON_LASER)
	if has_weapon(WEAPON_AXE):
		_add_next_weapon_upgrade(weapon_pool, WEAPON_AXE)
	return weapon_pool

func _add_next_weapon_upgrade(weapon_pool: Array[StatBuff], weapon_id: String) -> void:
	var next_upgrade: StatBuff = _get_next_weapon_upgrade(weapon_id)
	if next_upgrade != null:
		weapon_pool.append(next_upgrade)

func _get_next_weapon_upgrade(weapon_id: String) -> StatBuff:
	var upgrade_level: int = _get_weapon_upgrade_level(weapon_id)
	match weapon_id:
		WEAPON_SHOTGUN:
			match upgrade_level:
				0:
					return StatBuff.new(Stats.BuffableStats.SHOTGUN_EXTRA_PROJECTILE, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Cartucho doble")
				1:
					return StatBuff.new(Stats.BuffableStats.SHOTGUN_FIRE_RATE, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Recarga rapida")
				2:
					return StatBuff.new(Stats.BuffableStats.SHOTGUN_DAMAGE, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Municion pesada")
		WEAPON_LASER:
			match upgrade_level:
				0:
					return StatBuff.new(Stats.BuffableStats.LASER_EXTRA_BEAM, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Rayo gemelo")
				1:
					return StatBuff.new(Stats.BuffableStats.LASER_PIERCING, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Rayo perforante")
				2:
					return StatBuff.new(Stats.BuffableStats.LASER_DAMAGE, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Bobina sobrecargada")
		WEAPON_AXE:
			match upgrade_level:
				0:
					return StatBuff.new(Stats.BuffableStats.AXE_COOLDOWN, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Engranaje liviano")
				1:
					return StatBuff.new(Stats.BuffableStats.AXE_EXTRA_AXE, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Llave gemela")
				2:
					return StatBuff.new(Stats.BuffableStats.AXE_DAMAGE, 1.0, StatBuff.BuffType.ADD, StatBuff.Rarity.RARE, 1, "Filo reforzado")
	return null

func _get_weapon_upgrade_level(weapon_id: String) -> int:
	var upgrade_level: int = 0
	for stat_key in upgrade_counts_by_stat:
		var stat: Stats.BuffableStats = stat_key
		if _is_weapon_upgrade(stat) and _get_weapon_id_for_upgrade(stat) == weapon_id and int(upgrade_counts_by_stat[stat]) > 0:
			upgrade_level += 1
	return upgrade_level

func _can_offer_upgrade(buff: StatBuff) -> bool:
	if _is_weapon_unlock(buff.stat):
		return _can_offer_weapon_unlock(buff.stat)
	if _is_weapon_upgrade(buff.stat):
		return _can_offer_weapon_upgrade(buff.stat)
	if _get_upgrade_stack_count(buff.stat) >= MAX_UPGRADE_STACKS_PER_STAT:
		return false
	return _has_upgrade_stat_selected(buff.stat) or _get_selected_character_upgrade_count() < MAX_ACTIVE_UPGRADE_STATS

func _register_upgrade_stack(stat: Stats.BuffableStats) -> void:
	upgrade_counts_by_stat[stat] = _get_upgrade_stack_count(stat) + 1

func _get_upgrade_stack_count(stat: Stats.BuffableStats) -> int:
	return int(upgrade_counts_by_stat.get(stat, 0))

func _is_weapon_unlock(stat: Stats.BuffableStats) -> bool:
	return [
		Stats.BuffableStats.SHOTGUN_WEAPON,
		Stats.BuffableStats.LASER_WEAPON,
		Stats.BuffableStats.AXE_WEAPON,
	].has(stat)

func _is_weapon_upgrade(stat: Stats.BuffableStats) -> bool:
	return [
		Stats.BuffableStats.SHOTGUN_EXTRA_PROJECTILE,
		Stats.BuffableStats.SHOTGUN_FIRE_RATE,
		Stats.BuffableStats.SHOTGUN_DAMAGE,
		Stats.BuffableStats.LASER_EXTRA_BEAM,
		Stats.BuffableStats.LASER_PIERCING,
		Stats.BuffableStats.LASER_DAMAGE,
		Stats.BuffableStats.AXE_COOLDOWN,
		Stats.BuffableStats.AXE_EXTRA_AXE,
		Stats.BuffableStats.AXE_DAMAGE,
	].has(stat)

func _can_offer_weapon_unlock(stat: Stats.BuffableStats) -> bool:
	if weapons.size() >= MAX_WEAPON_SLOTS:
		return false
	return not has_weapon(_get_weapon_id_for_unlock(stat))

func _can_offer_weapon_upgrade(stat: Stats.BuffableStats) -> bool:
	return _get_upgrade_stack_count(stat) == 0 and has_weapon(_get_weapon_id_for_upgrade(stat))

func _apply_weapon_upgrade(stat: Stats.BuffableStats) -> void:
	if _is_weapon_unlock(stat):
		add_weapon(_get_weapon_id_for_unlock(stat))
		return
	var weapon: Weapon = get_weapon(_get_weapon_id_for_upgrade(stat))
	if weapon != null:
		weapon.apply_upgrade(stat)

func _has_upgrade_stat_selected(stat: Stats.BuffableStats) -> bool:
	return _get_upgrade_stack_count(stat) > 0

func _get_selected_character_upgrade_count() -> int:
	var selected_count: int = 0
	for stat_key in upgrade_counts_by_stat:
		var stat: Stats.BuffableStats = stat_key
		if int(upgrade_counts_by_stat[stat]) > 0 and _is_character_upgrade(stat):
			selected_count += 1
	return selected_count

func get_upgrade_stack_count_for_ui(stat: Stats.BuffableStats) -> int:
	return _get_upgrade_stack_count(stat)

func get_available_upgrade_stats_for_ui() -> Array[Stats.BuffableStats]:
	var selected_stats: Array[Stats.BuffableStats] = []
	for stat_key in upgrade_counts_by_stat:
		var stat: Stats.BuffableStats = stat_key
		if int(upgrade_counts_by_stat[stat]) > 0 and _is_character_upgrade(stat):
			selected_stats.append(stat)
	return selected_stats

func _is_character_upgrade(stat: Stats.BuffableStats) -> bool:
	return [
		Stats.BuffableStats.MAX_HEALTH,
		Stats.BuffableStats.MOVE_SPEED,
		Stats.BuffableStats.PICKUP_RANGE,
		Stats.BuffableStats.DAMAGE_REDUCTION,
		Stats.BuffableStats.SHIELD,
		Stats.BuffableStats.HEALTH_REGEN,
	].has(stat)

func _get_weapon_id_for_unlock(stat: Stats.BuffableStats) -> String:
	match stat:
		Stats.BuffableStats.SHOTGUN_WEAPON:
			return WEAPON_SHOTGUN
		Stats.BuffableStats.LASER_WEAPON:
			return WEAPON_LASER
		Stats.BuffableStats.AXE_WEAPON:
			return WEAPON_AXE
	return ""

func _get_weapon_id_for_upgrade(stat: Stats.BuffableStats) -> String:
	match stat:
		Stats.BuffableStats.SHOTGUN_EXTRA_PROJECTILE, Stats.BuffableStats.SHOTGUN_FIRE_RATE, Stats.BuffableStats.SHOTGUN_DAMAGE:
			return WEAPON_SHOTGUN
		Stats.BuffableStats.LASER_EXTRA_BEAM, Stats.BuffableStats.LASER_PIERCING, Stats.BuffableStats.LASER_DAMAGE:
			return WEAPON_LASER
		Stats.BuffableStats.AXE_COOLDOWN, Stats.BuffableStats.AXE_EXTRA_AXE, Stats.BuffableStats.AXE_DAMAGE:
			return WEAPON_AXE
	return ""

func has_weapon(weapon_id: String) -> bool:
	return bool(owned_weapon_ids.get(weapon_id, false))

func get_weapon(weapon_id: String) -> Weapon:
	match weapon_id:
		WEAPON_SHOTGUN:
			return shotgun_weapon
		WEAPON_LASER:
			return laser_weapon
		WEAPON_AXE:
			return axe_weapon
	return null

func add_weapon(weapon_id: String) -> bool:
	if weapon_id.is_empty() or has_weapon(weapon_id) or weapons.size() >= MAX_WEAPON_SLOTS:
		return false
	var weapon: Weapon = _get_or_create_weapon(weapon_id)
	if weapon == null:
		return false
	if not weapons.has(weapon):
		weapons.append(weapon)
	owned_weapon_ids[weapon_id] = true
	weapon.visible = true
	if weapon_id == WEAPON_SHOTGUN or weapon_id == WEAPON_LASER:
		held_weapon_order.append(weapon_id)
		_refresh_held_weapon_visuals()
	return true

func _get_or_create_weapon(weapon_id: String) -> Weapon:
	match weapon_id:
		WEAPON_SHOTGUN:
			if shotgun_weapon == null or not is_instance_valid(shotgun_weapon):
				shotgun_weapon = $Weapon as ShotgunWeapon
			return shotgun_weapon
		WEAPON_LASER:
			if laser_weapon == null or not is_instance_valid(laser_weapon):
				laser_weapon = LaserWeapon.new()
				laser_weapon.name = "LaserWeapon"
				add_child(laser_weapon)
			return laser_weapon
		WEAPON_AXE:
			if axe_weapon == null or not is_instance_valid(axe_weapon):
				axe_weapon = AxeWeapon.new()
				axe_weapon.name = "AxeWeapon"
				add_child(axe_weapon)
			return axe_weapon
	return null

func _setup_starting_weapon() -> void:
	weapons.clear()
	owned_weapon_ids.clear()
	held_weapon_order.clear()
	shotgun_weapon = $Weapon as ShotgunWeapon
	if shotgun_weapon != null:
		shotgun_weapon.visible = false
	if electric_sphere != null:
		electric_sphere.visible = false
	match Global.selected_character_id:
		0:
			add_weapon(WEAPON_SHOTGUN)
		1:
			add_weapon(WEAPON_AXE)
		2:
			add_weapon(WEAPON_LASER)
		_:
			add_weapon(WEAPON_SHOTGUN)

func get_weapon_muzzle_position(weapon_id: String) -> Vector2:
	match weapon_id:
		WEAPON_SHOTGUN:
			if shotgun_muzzle != null:
				return shotgun_muzzle.global_position
		WEAPON_LASER:
			if electric_sphere_muzzle != null:
				return electric_sphere_muzzle.global_position
	return global_position

func _refresh_held_weapon_visuals() -> void:
	if shotgun_visual != null:
		shotgun_visual.visible = false
	if electric_sphere != null:
		electric_sphere.visible = false
	for index in range(mini(held_weapon_order.size(), 2)):
		var anchor: Marker2D = right_hand_anchor if index == 0 else left_hand_anchor
		_place_held_weapon_visual(held_weapon_order[index], anchor)

func _place_held_weapon_visual(weapon_id: String, anchor: Marker2D) -> void:
	if anchor == null:
		return
	match weapon_id:
		WEAPON_SHOTGUN:
			if shotgun_visual != null:
				shotgun_visual.position = anchor.position
				shotgun_visual.visible = true
		WEAPON_LASER:
			if electric_sphere != null:
				electric_sphere.position = anchor.position
				electric_sphere.visible = true

func _apply_shield_upgrade() -> void:
	shield_enabled = true
	shield_ready = true
	shield_cooldown_timer = 0.0

func _tick_shield(delta: float) -> void:
	if not shield_enabled or shield_ready:
		return
	shield_cooldown_timer -= delta
	if shield_cooldown_timer <= 0.0:
		shield_ready = true
		Global.debug_log("Escudo listo")

func _tick_health_regen(delta: float) -> void:
	if stats == null or stats.current_health_regen <= 0.0 or stats.health <= 0.0:
		return
	if stats.health >= stats.current_max_health:
		return
	stats.health += stats.current_health_regen * delta

func _get_shield_cooldown_seconds() -> float:
	var shield_level: int = _get_upgrade_stack_count(Stats.BuffableStats.SHIELD)
	match shield_level:
		1:
			return 60.0
		2:
			return 45.0
		3:
			return 30.0
	return 60.0

func _get_upgrade_choice_names(choices: Array[StatBuff]) -> Array[String]:
	var names: Array[String] = []
	for choice in choices:
		var stat_name: String = String(Stats.BuffableStats.keys()[choice.stat]).capitalize()
		var type_name: String = String(StatBuff.BuffType.keys()[choice.buff_type]).capitalize()
		names.append("%s %s %.2f" % [stat_name, type_name, choice.buff_amount])
	return names

func TakeDamage(damage: int, damage_type: Stats.DamageType = Stats.DamageType.PHYSICAL, defense_penetration: float = 0.0) -> void:
	if stats == null:
		return
	if shield_ready:
		shield_ready = false
		shield_cooldown_timer = _get_shield_cooldown_seconds()
		Global.debug_log("Escudo bloqueo %s de dano. Recarga en %s segundos" % [damage, shield_cooldown_timer])
		return
	var final_damage: float = stats.take_damage(float(damage), damage_type, defense_penetration)
	if final_damage > 0.0:
		$CPUParticles2D.restart()
		_play_hit_flash()
		shake_camera(damage_camera_shake_strength, damage_camera_shake_duration)
		_start_invulnerability()
	Global.debug_log("Player recibio %s de dano (%s bruto). Vida: %s / %s" % [final_damage, damage, stats.health, stats.current_max_health])
	
	if stats.health <= 0: Die()
	
func Die() -> void:
	if is_dead:
		return
	is_dead = true
	Global.finish_run("death", stats)
	AudioManager.play_game_over()
	if Global.Player == self:
		Global.Player = null
	cleanup_runtime_ui()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://Scenes/DeathMenu.tscn")
	Global.debug_log("mori")

func _on_stats_health_changed(cur_health: float, max_health: float) -> void:
	_update_health_bar(cur_health, max_health)

func _update_health_bar(cur_health: float, max_health: float) -> void:
	if health_bar == null:
		return
	health_bar.max_value = maxf(max_health, 1.0)
	health_bar.value = cur_health

func _on_stats_changed() -> void:
	_update_fire_rate()
	_update_weapon_range()

func _update_fire_rate() -> void:
	if stats == null:
		return
	$Weapon/cd.wait_time = 1.0 / maxf(stats.current_fire_rate, 0.1)

func _get_current_speed() -> float:
	if stats == null:
		return speed
	return stats.current_move_speed

func _update_weapon_range() -> void:
	if stats == null or weapon_range_shape == null:
		return
	var circle_shape: CircleShape2D = weapon_range_shape.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = stats.current_weapon_range

func _collect_weapons() -> void:
	weapons.clear()
	for child in get_children():
		if child is Weapon:
			weapons.append(child)

func _tick_weapons(delta: float) -> void:
	if stats == null:
		return
	for weapon in weapons:
		weapon.tick(delta, self, stats)

func _apply_selected_character_sprite() -> void:
	var sprite: Sprite2D = $OneHanded
	if sprite == null:
		return
	var texture_index: int = clampi(Global.selected_character_id, 0, character_textures.size() - 1)
	sprite.texture = character_textures[texture_index]
	var target_height: float = 74.0
	var texture_height: float = float(sprite.texture.get_height())
	var character_scale: float = target_height / maxf(texture_height, 1.0)
	sprite.scale = Vector2(character_scale, character_scale)
	sprite.position = Vector2(0, -12)

func cleanup_runtime_ui() -> void:
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
	pause_menu_active = false

func toggle_pause_menu() -> void:
	if pause_menu_active:
		close_pause_menu()
	else:
		open_pause_menu()

func open_pause_menu() -> void:
	if pause_menu_active or pause_menu_scene == null:
		return
	pause_menu_active = true
	pause_menu = pause_menu_scene.instantiate()
	get_tree().root.add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.call("setup", self, stats)

func close_pause_menu() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
	pause_menu_active = false
	get_tree().paused = false

func _is_pause_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("enter"):
		return true
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_ENTER)

func _start_invulnerability() -> void:
	stats.set_invulnerable(true)
	invulnerability_timer = get_tree().create_timer(0.6)
	await invulnerability_timer.timeout
	if stats != null:
		stats.set_invulnerable(false)

func shake_camera(strength: float, duration: float) -> void:
	if camera == null:
		return
	camera_shake_strength = maxf(strength, camera_shake_strength)
	camera_shake_duration = maxf(duration, 0.01)
	camera_shake_time_left = maxf(duration, camera_shake_time_left)

func _tick_camera_shake(delta: float) -> void:
	if camera == null or camera_shake_time_left <= 0.0:
		return
	camera_shake_time_left -= delta
	if camera_shake_time_left <= 0.0:
		camera.offset = camera_base_offset
		camera_shake_strength = 0.0
		return
	var fade: float = camera_shake_time_left / maxf(camera_shake_duration, 0.01)
	var current_strength: float = camera_shake_strength * fade
	camera.offset = camera_base_offset + Vector2(
		randf_range(-current_strength, current_strength),
		randf_range(-current_strength, current_strength)
	)

func _play_hit_flash() -> void:
	if player_sprite == null:
		return
	if hit_flash_tween != null:
		hit_flash_tween.kill()
	player_sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.12)


func _on_cd_timeout() -> void:
	pass
