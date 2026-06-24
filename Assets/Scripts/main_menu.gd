extends Control

@export_file("*.tscn") var game_scene_path: String = "res://Scenes/CharacterSelectMenu.tscn"

func _ready() -> void:
	get_tree().paused = false
	$CenterContainer/VBoxContainer/StartButton.grab_focus()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
