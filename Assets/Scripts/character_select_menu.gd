extends Control

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/Nivel1/level_1.tscn"
@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/Menu.tscn"

var selected_index: int = 0
var transition_locked: bool = false
var character_names: Array[String] = [
	"Ingeniero",
	"Mecanico",
	"Electricista",
]

@onready var cards: Array[PanelContainer] = [
	$CenterContainer/VBoxContainer/CharacterRow/EngineerCard,
	$CenterContainer/VBoxContainer/CharacterRow/MechanicCard,
	$CenterContainer/VBoxContainer/CharacterRow/WelderCard,
]

@onready var character_buttons: Array[Button] = [
	$CenterContainer/VBoxContainer/CharacterRow/EngineerCard/CardContent/ChooseButton,
	$CenterContainer/VBoxContainer/CharacterRow/MechanicCard/CardContent/ChooseButton,
	$CenterContainer/VBoxContainer/CharacterRow/WelderCard/CardContent/ChooseButton,
]

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	get_tree().paused = false
	for index in range(character_buttons.size()):
		character_buttons[index].pressed.connect(_on_character_button_pressed.bind(index))
		character_buttons[index].mouse_entered.connect(_select_character.bind(index))
	back_button.pressed.connect(_on_back_button_pressed)
	_select_character(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_select_character(wrapi(selected_index - 1, 0, character_buttons.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_select_character(wrapi(selected_index + 1, 0, character_buttons.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or _is_confirm_key(event):
		if get_viewport().gui_get_focus_owner() == back_button:
			_go_back()
		else:
			_start_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()

func _select_character(index: int) -> void:
	selected_index = clampi(index, 0, character_buttons.size() - 1)
	for card_index in range(cards.size()):
		cards[card_index].modulate = Color(1.0, 0.92, 0.72, 1.0) if card_index == selected_index else Color(0.82, 0.82, 0.82, 1.0)
	character_buttons[selected_index].grab_focus()

func _start_game() -> void:
	if transition_locked:
		return
	transition_locked = true
	Global.selected_character_id = selected_index
	Global.selected_character_name = character_names[selected_index]
	get_tree().call_deferred("change_scene_to_file", game_scene_path)

func _on_character_button_pressed(index: int) -> void:
	if transition_locked:
		return
	_select_character(index)
	_start_game()

func _on_back_button_pressed() -> void:
	_go_back()

func _go_back() -> void:
	if transition_locked:
		return
	transition_locked = true
	get_tree().call_deferred("change_scene_to_file", main_menu_scene_path)

func _is_confirm_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE)
