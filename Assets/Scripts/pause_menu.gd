extends CanvasLayer

const MAIN_MENU_SCENE_PATH: String = "res://Scenes/Menu.tscn"

var player: Player
var stats: Stats

@onready var upgrade_icons: HBoxContainer = $Panel/MarginContainer/VBoxContainer/UpgradeIcons
@onready var stats_label: Label = $Panel/MarginContainer/VBoxContainer/StatsLabel
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/ContinueButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	continue_button.grab_focus()

func setup(_player: Player, _stats: Stats) -> void:
	player = _player
	stats = _stats
	if stats != null:
		if not stats.health_changed.is_connected(_on_stats_health_changed):
			stats.health_changed.connect(_on_stats_health_changed)
		if not stats.stats_changed.is_connected(_refresh):
			stats.stats_changed.connect(_refresh)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if _is_pause_input(event):
		_close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	_update_upgrade_icons()
	_update_stats_label()

func _update_upgrade_icons() -> void:
	if player == null:
		return
	var upgrade_stats: Array[Stats.BuffableStats] = player.get_available_upgrade_stats_for_ui()
	for index in range(upgrade_icons.get_child_count()):
		var icon_label: Label = upgrade_icons.get_child(index) as Label
		if icon_label == null:
			continue
		if index >= upgrade_stats.size():
			icon_label.text = "--\n0/%s" % Player.MAX_UPGRADE_STACKS_PER_STAT
			continue
		var stat: Stats.BuffableStats = upgrade_stats[index]
		icon_label.text = "%s\n%s/%s" % [_get_upgrade_label(stat), player.get_upgrade_stack_count_for_ui(stat), Player.MAX_UPGRADE_STACKS_PER_STAT]

func _update_stats_label() -> void:
	if stats == null:
		stats_label.text = "Sin estadisticas"
		return
	stats_label.text = "\n".join([
		"Nivel: %s" % stats.level,
		"Vida: %s / %s" % [_format_number(stats.health), _format_number(stats.current_max_health)],
		"Dano: %s" % _format_number(stats.current_attack),
		"Defensa: %s" % _format_number(stats.current_defense),
		"Velocidad: %s" % _format_number(stats.current_move_speed),
		"Disparos/seg: %s" % _format_number(stats.current_fire_rate),
		"Rango arma: %s" % _format_number(stats.current_weapon_range),
		"Rango gemas: %s" % _format_number(stats.current_pickup_range),
		"Regeneracion: %s/s" % _format_number(stats.current_health_regen),
	])

func _get_upgrade_label(stat: Stats.BuffableStats) -> String:
	match stat:
		Stats.BuffableStats.MAX_HEALTH:
			return "HP"
		Stats.BuffableStats.ATTACK:
			return "ATK"
		Stats.BuffableStats.MOVE_SPEED:
			return "SPD"
		Stats.BuffableStats.FIRE_RATE:
			return "FR"
		Stats.BuffableStats.DEFENSE:
			return "DEF"
		Stats.BuffableStats.PICKUP_RANGE:
			return "MAG"
		Stats.BuffableStats.WEAPON_RANGE:
			return "RNG"
		Stats.BuffableStats.DAMAGE_REDUCTION:
			return "ARM"
		Stats.BuffableStats.SHIELD:
			return "SHD"
		Stats.BuffableStats.HEALTH_REGEN:
			return "RGN"
		Stats.BuffableStats.PHYSICAL_RESISTANCE:
			return "PHY"
		Stats.BuffableStats.ELECTRIC_RESISTANCE:
			return "ELE"
		Stats.BuffableStats.FIRE_RESISTANCE:
			return "FIR"
		Stats.BuffableStats.PROJECTILE_COUNT:
			return "PRJ"
		Stats.BuffableStats.LASER_WEAPON:
			return "LAS"
		Stats.BuffableStats.AXE_WEAPON:
			return "AXE"
		Stats.BuffableStats.SHOTGUN_WEAPON:
			return "SG"
	return "UP"

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.1f" % value

func _is_pause_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("enter"):
		return true
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_ENTER)

func _close() -> void:
	if player != null and is_instance_valid(player):
		player.close_pause_menu()
	else:
		get_tree().paused = false
		queue_free()

func _on_stats_health_changed(_cur_health: float, _max_health: float) -> void:
	_update_stats_label()

func _on_continue_button_pressed() -> void:
	_close()

func _on_main_menu_button_pressed() -> void:
	Global.stop_run()
	if Global.Player == player:
		Global.Player = null
	if player != null and is_instance_valid(player):
		player.cleanup_runtime_ui()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
