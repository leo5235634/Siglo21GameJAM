extends Node


var Player: Player = null
var debug_enabled: bool = false
var env_values: Dictionary[String, String] = {}
var survived_time: float = 0.0
var enemies_killed: int = 0
var is_run_active: bool = false
var selected_character_id: int = 0
var selected_character_name: String = "Ingeniero"
var last_run_summary: Dictionary = {}

signal survived_time_changed(time_seconds: float)
signal enemies_killed_changed(kill_count: int)

func _ready() -> void:
	env_values = _read_env_file()
	debug_enabled = _read_debug_enabled()

func _process(delta: float) -> void:
	if not is_run_active:
		return
	survived_time += delta
	survived_time_changed.emit(survived_time)

func start_run() -> void:
	survived_time = 0.0
	enemies_killed = 0
	last_run_summary.clear()
	is_run_active = true
	survived_time_changed.emit(survived_time)
	enemies_killed_changed.emit(enemies_killed)

func stop_run() -> void:
	is_run_active = false

func finish_run(result: String, player_stats: Stats = null) -> void:
	is_run_active = false
	last_run_summary = {
		"result": result,
		"time_seconds": survived_time,
		"kills": enemies_killed,
		"character_name": selected_character_name,
		"level": 1,
		"experience": 0,
		"max_health": 0,
	}
	if player_stats != null:
		last_run_summary["level"] = player_stats.level
		last_run_summary["experience"] = int(player_stats.experience)
		last_run_summary["max_health"] = int(player_stats.current_max_health)

func get_run_summary_text() -> String:
	if last_run_summary.is_empty():
		return "No hay resumen de partida disponible."
	var character_name: String = str(last_run_summary.get("character_name", selected_character_name))
	var time_text: String = format_time(float(last_run_summary.get("time_seconds", 0.0)))
	var level: int = int(last_run_summary.get("level", 1))
	var kills: int = int(last_run_summary.get("kills", 0))
	var experience: int = int(last_run_summary.get("experience", 0))
	var max_health: int = int(last_run_summary.get("max_health", 0))
	return "Personaje: %s\nTiempo sobrevivido: %s\nNivel alcanzado: %s\nEnemigos derrotados: %s\nExperiencia obtenida: %s\nVida maxima: %s" % [character_name, time_text, level, kills, experience, max_health]

func format_time(time_seconds: float) -> String:
	var total_seconds: int = max(0, int(floor(time_seconds)))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func register_enemy_kill() -> void:
	enemies_killed += 1
	enemies_killed_changed.emit(enemies_killed)

func debug_log(message: String) -> void:
	if debug_enabled:
		print(message)

func _read_debug_enabled() -> bool:
	var raw_value: String = _get_env_value("SIGLO21_DEBUG").to_lower()
	return raw_value == "1" or raw_value == "true" or raw_value == "yes" or raw_value == "on"

func _get_env_value(key: String) -> String:
	if env_values.has(key):
		return env_values[key]
	return OS.get_environment(key)

func _read_env_file() -> Dictionary[String, String]:
	var values: Dictionary[String, String] = {}
	if not FileAccess.file_exists("res://.env"):
		return values
	var file: FileAccess = FileAccess.open("res://.env", FileAccess.READ)
	if file == null:
		return values
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		_parse_env_line(line, values)
	return values

func _parse_env_line(line: String, values: Dictionary[String, String]) -> void:
	if line.begins_with("$env:"):
		line = line.substr(5)
	var separator_index: int = line.find("=")
	if separator_index == -1:
		return
	var key: String = line.substr(0, separator_index).strip_edges()
	var value: String = line.substr(separator_index + 1).strip_edges()
	value = _strip_env_quotes(value)
	if not key.is_empty():
		values[key] = value

func _strip_env_quotes(value: String) -> String:
	if value.length() >= 2:
		var first_char: String = value.substr(0, 1)
		var last_char: String = value.substr(value.length() - 1, 1)
		if (first_char == "\"" and last_char == "\"") or (first_char == "'" and last_char == "'"):
			return value.substr(1, value.length() - 2)
	return value
