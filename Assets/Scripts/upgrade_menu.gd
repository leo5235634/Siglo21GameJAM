extends CanvasLayer

var player: Player
var choices: Array[StatBuff] = []
var buttons: Array[Button] = []
var selected_index: int = 0
var choice_locked: bool = false

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var option_buttons: VBoxContainer = $Panel/VBoxContainer/OptionButtons

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	buttons = [
		$Panel/VBoxContainer/OptionButtons/OptionButton1,
		$Panel/VBoxContainer/OptionButtons/OptionButton2,
		$Panel/VBoxContainer/OptionButtons/OptionButton3,
	]
	for index in range(buttons.size()):
		buttons[index].pressed.connect(_on_option_pressed.bind(index))
		buttons[index].mouse_entered.connect(_select_option.bind(index))
		buttons[index].process_mode = Node.PROCESS_MODE_ALWAYS
	_update_buttons()
	_select_option(0)

func setup(_player: Player, _choices: Array[StatBuff], level: int) -> void:
	player = _player
	choices = _choices
	if is_node_ready():
		title_label.text = "Nivel %s" % level
		_update_buttons()
		_select_option(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_select_option(wrapi(selected_index - 1, 0, buttons.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_select_option(wrapi(selected_index + 1, 0, buttons.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or _is_confirm_key(event):
		_choose_selected_option()
		get_viewport().set_input_as_handled()

func _is_confirm_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE)

func _update_buttons() -> void:
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		button.disabled = index >= choices.size()
		if index < choices.size():
			button.text = _get_choice_text(choices[index])
		else:
			button.text = "-"

func _select_option(index: int) -> void:
	selected_index = clampi(index, 0, buttons.size() - 1)
	buttons[selected_index].grab_focus()

func _choose_selected_option() -> void:
	_on_option_pressed(selected_index)

func _on_option_pressed(index: int) -> void:
	if choice_locked or player == null or index < 0 or index >= choices.size():
		return
	choice_locked = true
	player.choose_upgrade(index)
	queue_free()

func _get_choice_text(choice: StatBuff) -> String:
	if _is_weapon_choice(choice.stat):
		return _get_weapon_choice_text(choice)
	if choice.stat == Stats.BuffableStats.SHIELD:
		return _get_shield_choice_text(choice)
	if choice.stat == Stats.BuffableStats.HEALTH_REGEN:
		return _get_health_regen_choice_text(choice)
	var stat_name: String = _get_stat_name(choice.stat)
	var rarity_name: String = _get_rarity_name(choice.rarity)
	var prefix: String = "[%s] " % rarity_name
	if not choice.display_name.is_empty():
		prefix += "%s - " % choice.display_name
	match choice.buff_type:
		StatBuff.BuffType.ADD:
			if _is_percentage_add_stat(choice.stat):
				return "%s+%d%% %s" % [prefix, roundi(choice.buff_amount * 100.0), stat_name]
			return "%s+%s %s" % [prefix, _format_number(choice.buff_amount), stat_name]
		StatBuff.BuffType.MULTIPLY:
			return "%s+%d%% %s" % [prefix, roundi(choice.buff_amount * 100.0), stat_name]
	return "%s%s" % [prefix, stat_name]

func _get_rarity_name(rarity: StatBuff.Rarity) -> String:
	match rarity:
		StatBuff.Rarity.COMMON:
			return "Comun"
		StatBuff.Rarity.RARE:
			return "Rara"
		StatBuff.Rarity.EPIC:
			return "Epica"
	return "Comun"

func _get_stat_name(stat: Stats.BuffableStats) -> String:
	match stat:
		Stats.BuffableStats.MAX_HEALTH:
			return "vida maxima"
		Stats.BuffableStats.DEFENSE:
			return "defensa"
		Stats.BuffableStats.ATTACK:
			return "dano"
		Stats.BuffableStats.MOVE_SPEED:
			return "velocidad"
		Stats.BuffableStats.FIRE_RATE:
			return "cadencia"
		Stats.BuffableStats.DAMAGE_REDUCTION:
			return "reduccion de dano"
		Stats.BuffableStats.PHYSICAL_RESISTANCE:
			return "resistencia fisica"
		Stats.BuffableStats.ELECTRIC_RESISTANCE:
			return "resistencia electrica"
		Stats.BuffableStats.FIRE_RESISTANCE:
			return "resistencia al fuego"
		Stats.BuffableStats.PICKUP_RANGE:
			return "rango de gemas"
		Stats.BuffableStats.PROJECTILE_COUNT:
			return "proyectiles"
		Stats.BuffableStats.WEAPON_RANGE:
			return "rango de arma"
		Stats.BuffableStats.HEALTH_REGEN:
			return "regeneracion"
	return String(Stats.BuffableStats.keys()[stat]).to_lower().replace("_", " ")

func _is_percentage_add_stat(stat: Stats.BuffableStats) -> bool:
	return [
		Stats.BuffableStats.DAMAGE_REDUCTION,
		Stats.BuffableStats.PHYSICAL_RESISTANCE,
		Stats.BuffableStats.ELECTRIC_RESISTANCE,
		Stats.BuffableStats.FIRE_RESISTANCE,
	].has(stat)

func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.2f" % value

func _is_weapon_choice(stat: Stats.BuffableStats) -> bool:
	return [
		Stats.BuffableStats.SHOTGUN_WEAPON,
		Stats.BuffableStats.SHOTGUN_EXTRA_PROJECTILE,
		Stats.BuffableStats.SHOTGUN_FIRE_RATE,
		Stats.BuffableStats.SHOTGUN_DAMAGE,
		Stats.BuffableStats.LASER_WEAPON,
		Stats.BuffableStats.LASER_EXTRA_BEAM,
		Stats.BuffableStats.LASER_PIERCING,
		Stats.BuffableStats.LASER_DAMAGE,
		Stats.BuffableStats.AXE_WEAPON,
		Stats.BuffableStats.AXE_COOLDOWN,
		Stats.BuffableStats.AXE_EXTRA_AXE,
		Stats.BuffableStats.AXE_DAMAGE,
	].has(stat)

func _get_weapon_choice_text(choice: StatBuff) -> String:
	var rarity_name: String = _get_rarity_name(choice.rarity)
	match choice.stat:
		Stats.BuffableStats.SHOTGUN_WEAPON:
			return "[%s] Escopeta - Desbloquea arma" % rarity_name
		Stats.BuffableStats.SHOTGUN_EXTRA_PROJECTILE:
			return "[%s] Cartucho doble - +1 bala de escopeta" % rarity_name
		Stats.BuffableStats.SHOTGUN_FIRE_RATE:
			return "[%s] Recarga rapida - +30%% cadencia de escopeta" % rarity_name
		Stats.BuffableStats.SHOTGUN_DAMAGE:
			return "[%s] Municion pesada - +25%% dano de escopeta" % rarity_name
		Stats.BuffableStats.LASER_WEAPON:
			return "[%s] Bobina de rayos - Desbloquea arma" % rarity_name
		Stats.BuffableStats.LASER_EXTRA_BEAM:
			return "[%s] Rayo gemelo - +1 rayo" % rarity_name
		Stats.BuffableStats.LASER_PIERCING:
			return "[%s] Rayo perforante - Atraviesa enemigos" % rarity_name
		Stats.BuffableStats.LASER_DAMAGE:
			return "[%s] Bobina sobrecargada - +25%% dano de rayo" % rarity_name
		Stats.BuffableStats.AXE_WEAPON:
			return "[%s] Llave orbital - Desbloquea llave" % rarity_name
		Stats.BuffableStats.AXE_COOLDOWN:
			return "[%s] Engranaje liviano - Recarga 1.2s" % rarity_name
		Stats.BuffableStats.AXE_EXTRA_AXE:
			return "[%s] Llave gemela - +1 llave" % rarity_name
		Stats.BuffableStats.AXE_DAMAGE:
			return "[%s] Acero reforzado - +25%% dano de llave" % rarity_name
	return "[%s] %s" % [rarity_name, choice.display_name]

func _get_shield_choice_text(choice: StatBuff) -> String:
	var rarity_name: String = _get_rarity_name(choice.rarity)
	var current_level: int = 0
	if player != null:
		current_level = player.get_upgrade_stack_count_for_ui(Stats.BuffableStats.SHIELD)
	match current_level + 1:
		1:
			return "[%s] Escudo de emergencia - Bloquea 1 golpe cada 60s" % rarity_name
		2:
			return "[%s] Escudo calibrado - Recarga 45s" % rarity_name
		3:
			return "[%s] Escudo acelerado - Recarga 30s" % rarity_name
	return "[%s] %s" % [rarity_name, choice.display_name]

func _get_health_regen_choice_text(choice: StatBuff) -> String:
	var rarity_name: String = _get_rarity_name(choice.rarity)
	return "[%s] %s - +%s vida/s" % [rarity_name, choice.display_name, _format_number(choice.buff_amount)]
