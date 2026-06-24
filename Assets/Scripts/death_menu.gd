extends Control

const MAIN_MENU_SCENE_PATH: String = "res://Scenes/Menu.tscn"

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var summary_label: Label = $CenterContainer/VBoxContainer/SummaryLabel

func _ready() -> void:
	get_tree().paused = false
	summary_label.text = Global.get_run_summary_text()
	back_button.grab_focus()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
