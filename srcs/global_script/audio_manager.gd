extends Node
class_name MyAudioManager

#region AUDIO PLAYERS

# Sound Effects Players
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var ui_sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Background Music Player
@onready var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()

#endregion

#region AUDIO RESOURCES

# Export variables for editor configuration (optional)
@export_group("UI Sounds")
@export var ui_click_sound_path: String = "res://assets/audio/ui/click.mp3"

@export_group("Game SFX")
@export var wall_collision_sound_path: String = "res://assets/audio/sfx/wall_collision.mp3"
@export var player_fall_sound_path: String = "res://assets/audio/sfx/player_fall.mp3"
@export var ice_break_sound_path: String = "res://assets/audio/sfx/ice_break.mp3"
@export var game_over_sound_path: String = "res://assets/audio/sfx/game-over.mp3"
@export var victory_sound_path: String = "res://assets/audio/sfx/victory.mp3"

@export_group("Background Music")
@export var menu_music_path: String = "res://assets/audio/music/menu_music.mp3"
#@export var level_music_path: String = "res://assets/audio/music/level_music.mp3"

# UI Sound Effects (da impostare nell'editor o tramite codice)
var ui_click_sound: AudioStream
var ui_hover_sound: AudioStream

# Game Sound Effects
var wall_collision_sound: AudioStream
var player_fall_sound: AudioStream
var ice_break_sound: AudioStream
var game_over_sound: AudioStream
var victory_sound: AudioStream

# Background Music
var menu_background_music: AudioStream
var level_background_music: AudioStream

#endregion

#region VOLUME SETTINGS

var master_volume: float = 0.5
var sfx_volume: float = 0.5
var ui_volume: float = 0.5
var music_volume: float = 0.2

#endregion

#region INITIALIZATION

func _ready() -> void:
	"""Initialize audio system"""
	setup_audio_players()
	load_audio_settings()
	load_default_audio_resources()
	GlobalVariables.d_info("AudioManager initialized", "AUDIO")

func setup_audio_players() -> void:
	"""Setup audio players with proper configuration"""
	# Add players to the scene tree
	add_child(sfx_player)
	add_child(ui_sfx_player)
	add_child(bgm_player)
	
	# Configure SFX players
	sfx_player.name = "SFXPlayer"
	sfx_player.volume_db = linear_to_db(sfx_volume * master_volume)
	
	ui_sfx_player.name = "UISFXPlayer"
	ui_sfx_player.volume_db = linear_to_db(sfx_volume * master_volume)
	
	# Configure BGM player
	bgm_player.name = "BGMPlayer"
	bgm_player.volume_db = linear_to_db(music_volume * master_volume)
	bgm_player.autoplay = false

func load_audio_settings() -> void:
	"""Load audio settings from save file or use defaults"""
	# TODO: Implementare caricamento impostazioni da file di salvataggio
	# Per ora usa i valori di default
	update_volume_levels()

#endregion

#region VOLUME CONTROL

func set_master_volume(volume: float) -> void:
	"""Set master volume (0.0 - 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)
	update_volume_levels()

func set_sfx_volume(volume: float) -> void:
	"""Set sound effects volume (0.0 - 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	update_volume_levels()

func set_ui_volume(volume: float) -> void:
	"""Set UI sound effects volume (0.0 - 1.0)"""
	ui_volume = clamp(volume, 0.0, 1.0)
	update_volume_levels()

func set_music_volume(volume: float) -> void:
	"""Set background music volume (0.0 - 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	update_volume_levels()

func update_volume_levels() -> void:
	"""Update all audio players with current volume settings"""
	var sfx_db = linear_to_db(sfx_volume * master_volume)
	var ui_db = linear_to_db(ui_volume * master_volume)
	var music_db = linear_to_db(music_volume * master_volume)
	
	sfx_player.volume_db = sfx_db
	ui_sfx_player.volume_db = ui_db
	bgm_player.volume_db = music_db

#endregion

#region UI SOUND EFFECTS

func play_ui_sound(sound_type: String) -> void:
	"""Play UI sound effect by type"""
	match sound_type:
		"click":
			play_ui_click()
		_:
			GlobalVariables.d_warning("Unknown UI sound type: " + sound_type, "AUDIO")

func play_ui_click() -> void:
	"""Play UI click sound effect"""
	if ui_click_sound != null:
		ui_sfx_player.stream = ui_click_sound
		ui_sfx_player.play()
		GlobalVariables.d_verbose("Playing UI click sound", "AUDIO")

func play_ui_hover() -> void:
	"""Play UI hover sound effect"""
	if ui_hover_sound != null:
		ui_sfx_player.stream = ui_hover_sound
		ui_sfx_player.play()
		GlobalVariables.d_verbose("Playing UI hover sound", "AUDIO")

#endregion

#region GAME SOUND EFFECTS

func play_game_sfx(sfx_type: String) -> void:
	"""Play game sound effect by type"""
	match sfx_type:
		"wall_collision":
			play_wall_collision()
		"player_fall":
			play_player_fall()
		"ice_break":
			play_ice_break()
		"game_over":
			play_game_over()
		"victory":
			play_victory()
		_:
			GlobalVariables.d_warning("Unknown game SFX type: " + sfx_type, "AUDIO")

func play_wall_collision() -> void:
	"""Play wall collision sound effect"""
	if wall_collision_sound != null:
		sfx_player.stream = wall_collision_sound
		sfx_player.play()
		GlobalVariables.d_verbose("Playing wall collision sound", "AUDIO")

func play_player_fall() -> void:
	"""Play player falling into hole sound effect"""
	if player_fall_sound != null:
		sfx_player.stream = player_fall_sound
		sfx_player.play()
		GlobalVariables.d_info("Playing player fall sound", "AUDIO")

func play_ice_break() -> void:
	"""Play ice breaking sound effect"""
	if ice_break_sound != null:
		sfx_player.stream = ice_break_sound
		sfx_player.play()
		GlobalVariables.d_verbose("Playing ice break sound", "AUDIO")

func play_game_over() -> void:
	"""Play game over sound effect"""
	if game_over_sound != null:
		sfx_player.stream = game_over_sound
		sfx_player.play()
		GlobalVariables.d_info("Playing game over sound", "AUDIO")

func play_victory() -> void:
	"""Play victory sound effect"""
	if victory_sound != null:
		sfx_player.stream = victory_sound
		sfx_player.play()
		GlobalVariables.d_info("Playing victory sound", "AUDIO")

#endregion

#region BACKGROUND MUSIC

func play_background_music(music_type: String) -> void:
	"""Play background music by type"""
	match music_type:
		"menu":
			play_menu_music()
		"level":
			play_level_music()
		_:
			GlobalVariables.d_warning("Unknown background music type: " + music_type, "AUDIO")

func play_menu_music() -> void:
	"""Start playing menu background music"""
	if menu_background_music != null:
		bgm_player.stream = menu_background_music
		bgm_player.play()
		GlobalVariables.d_info("Started menu background music", "AUDIO")

func play_level_music() -> void:
	"""Start playing level background music"""
	if level_background_music != null:
		bgm_player.stream = level_background_music
		bgm_player.play()
		GlobalVariables.d_info("Started level background music", "AUDIO")

func stop_music() -> void:
	"""Stop background music"""
	bgm_player.stop()
	GlobalVariables.d_verbose("Stopped background music", "AUDIO")

func fade_out_music(duration: float = 1.0) -> void:
	"""Fade out background music over specified duration"""
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", -80, duration)
	tween.tween_callback(stop_music)
	GlobalVariables.d_verbose("Fading out background music over %.1fs" % duration, "AUDIO")

func fade_in_music(duration: float = 1.0) -> void:
	"""Fade in background music over specified duration"""
	var target_volume = linear_to_db(music_volume * master_volume)
	bgm_player.volume_db = -80
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", target_volume, duration)
	GlobalVariables.d_verbose("Fading in background music over %.1fs" % duration, "AUDIO")

#endregion

#region UTILITY FUNCTIONS

func is_music_playing() -> bool:
	"""Check if background music is currently playing"""
	return bgm_player.playing

func get_music_position() -> float:
	"""Get current position in background music"""
	return bgm_player.get_playback_position()

func set_music_position(position: float) -> void:
	"""Set position in background music"""
	bgm_player.seek(position)

#endregion

#region AUDIO RESOURCE LOADING

func load_ui_sounds(click_path: String) -> void:
	"""Load UI sound effects from file paths"""
	ui_click_sound = load(click_path)
	GlobalVariables.d_info("Loaded UI sounds", "AUDIO")

func load_game_sounds(wall_path: String, fall_path: String, ice_break_path: String, game_over_path, victory_path: String) -> void:
	"""Load game sound effects from file paths"""
	wall_collision_sound = load(wall_path)
	player_fall_sound = load(fall_path)
	ice_break_sound = load(ice_break_path)
	game_over_sound = load(game_over_path)
	victory_sound = load(victory_path)
	GlobalVariables.d_info("Loaded game sounds", "AUDIO")

func load_background_music(menu_path: String = "", level_path: String = "") -> void:
	"""Load background music from file paths"""
	if menu_path != "":
		menu_background_music = load(menu_path)
		menu_background_music.loop = true
	if level_path != "":
		level_background_music = load(level_path)
		level_background_music.loop = true
	GlobalVariables.d_info("Loaded background music", "AUDIO")

func load_default_audio_resources() -> void:
	"""Load default audio resources - modify paths here"""
	# Try to load from export paths first, then fallback to hardcoded paths
	
	# UI Sounds
	if ResourceLoader.exists(ui_click_sound_path):
		load_ui_sounds(ui_click_sound_path)

	# Game Sounds
	if ResourceLoader.exists(wall_collision_sound_path):
		load_game_sounds(
			wall_collision_sound_path,
			player_fall_sound_path,
			ice_break_sound_path,
			game_over_sound_path,
			victory_sound_path
		)
	
	# Background Music
	if ResourceLoader.exists(menu_music_path):
		load_background_music(menu_music_path)
	
	GlobalVariables.d_info("Audio resources loading attempted (files loaded if available)", "AUDIO")

#endregion
