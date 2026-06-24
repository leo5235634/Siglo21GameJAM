extends Node

const GAME_START_SOUND: AudioStream = preload("res://Assets/Sounds/game-start.mp3")
const BUTTON_UI_SOUND: AudioStream = preload("res://Assets/Sounds/button-ui-sound.mp3")
const GAME_OVER_SOUND: AudioStream = preload("res://Assets/Sounds/game-over.mp3")
const LEVEL_UP_SOUND: AudioStream = preload("res://Assets/Sounds/levelup-sound.mp3")
const MUSIC_SOUND: AudioStream = preload("res://Assets/Sounds/music-sound.mp3")
const SHOTGUN_SOUND: AudioStream = preload("res://Assets/Sounds/shotgun-sound.mp3")

const MUSIC_VOLUME_DB: float = -16.0
const SFX_VOLUME_DB: float = -2.0
const UI_VOLUME_DB: float = -8.0
const SHOTGUN_VOLUME_DB: float = -10.0
const UI_SOUND_COOLDOWN_SECONDS: float = 0.05
const STARTUP_UI_MUTE_SECONDS: float = 0.25

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var next_sfx_player_index: int = 0
var last_ui_sound_time_msec: int = -1000
var startup_time_msec: int = 0
var game_start_played: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	startup_time_msec = Time.get_ticks_msec()
	_create_players()
	_register_existing_buttons(get_tree().root)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	play_game_start_once()
	play_music()

func play_game_start_once() -> void:
	if game_start_played:
		return
	game_start_played = true
	play_game_start()

func play_game_start() -> void:
	_play_sfx(GAME_START_SOUND, SFX_VOLUME_DB)

func play_music() -> void:
	if music_player == null or music_player.playing:
		return
	var stream: AudioStream = MUSIC_SOUND.duplicate()
	_set_stream_loop(stream)
	music_player.stream = stream
	music_player.volume_db = MUSIC_VOLUME_DB
	music_player.play()

func play_button_ui() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - startup_time_msec < int(STARTUP_UI_MUTE_SECONDS * 1000.0):
		return
	if now_msec - last_ui_sound_time_msec < int(UI_SOUND_COOLDOWN_SECONDS * 1000.0):
		return
	last_ui_sound_time_msec = now_msec
	_play_sfx(BUTTON_UI_SOUND, UI_VOLUME_DB)

func play_game_over() -> void:
	_play_sfx(GAME_OVER_SOUND, SFX_VOLUME_DB)

func play_level_up() -> void:
	_play_sfx(LEVEL_UP_SOUND, SFX_VOLUME_DB)

func play_shotgun() -> void:
	_play_sfx(SHOTGUN_SOUND, SHOTGUN_VOLUME_DB)

func _create_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)

	for index in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxPlayer%s" % index
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		sfx_players.append(player)

func _play_sfx(stream: AudioStream, volume_db: float) -> void:
	if stream == null or sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _get_next_sfx_player()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func _get_next_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	var player: AudioStreamPlayer = sfx_players[next_sfx_player_index]
	next_sfx_player_index = wrapi(next_sfx_player_index + 1, 0, sfx_players.size())
	return player

func _on_node_added(node: Node) -> void:
	if node is Button:
		_register_button(node as Button)

func _register_existing_buttons(node: Node) -> void:
	if node is Button:
		_register_button(node as Button)
	for child in node.get_children():
		_register_existing_buttons(child)

func _register_button(button: Button) -> void:
	if button.has_meta("audio_manager_ui_registered"):
		return
	button.set_meta("audio_manager_ui_registered", true)
	button.focus_entered.connect(play_button_ui)
	button.mouse_entered.connect(play_button_ui)
	button.pressed.connect(play_button_ui)

func _set_stream_loop(stream: AudioStream) -> void:
	for property in stream.get_property_list():
		if String(property["name"]) == "loop":
			stream.set("loop", true)
			return
