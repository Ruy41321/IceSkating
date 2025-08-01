class_name LevelOffline
extends Node2D

#region SCENE REFERENCES

var tilemap: TileMapLayer

#endregion

#region CONFIGURATION

@export var test_custom_map: bool = false

var player_path: String = GlobalVariables.player_offline_path

#endregion

#region INITIALIZATION

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	"""Initialize the offline level and load the appropriate map"""
	
	# Start background music for level
	AudioManager.play_background_music("level")
	
	LevelManager.current_moves_count = 0
	
	tilemap = LevelManager.tilemap
	if tilemap == null:
		handle_map_loading_error()
		return

	load_and_setup_map()
		
	finalize_level_setup()


func load_and_setup_map() -> bool:
	"""Load map data and setup the grid"""
	add_child(tilemap)
	spawn_player()
	return true

func handle_map_loading_error() -> void:
	"""Handle map loading error"""
	GlobalVariables.map_gen_error = true
	get_tree().change_scene_to_file(GlobalVariables.start_menu_path)

func finalize_level_setup() -> void:
	"""Finalize level setup with background tasks"""
	
	# Generate next map in advance
	if not LevelManager.play_always_with_main_map:
		MapManager.generate_map_threaded(LevelManager.get_reserve_map_name(), LevelManager.get_offline_difficulty())
	
	# FAKE WIN CONDITION for testing
	if LevelManager.use_fake_wins:
		await get_tree().create_timer(3).timeout
		LevelManager.handle_end_game(true)

#endregion

#region PLAYER SPAWNING

func spawn_player() -> void:
	"""Spawn the player at the designated spawn position"""
	if not validate_spawn_position():
		return
		
	var player_instance = create_player_instance()
	if player_instance == null:
		return
		
	setup_player_instance(player_instance)
	add_child(player_instance)
	
	GlobalVariables.d_info("Player spawned at grid position " + str(LevelManager.player_spawn_position) + " (world: " + str(player_instance.position) + ")", "LEVEL_MANAGEMENT")

func validate_spawn_position() -> bool:
	"""Validate that the spawn position is valid"""
	if LevelManager.player_spawn_position == Vector2i(-1, -1):
		GlobalVariables.d_error("Player spawn position not found!", "LEVEL_MANAGEMENT")
		return false
	return true

func create_player_instance() -> Node:
	"""Create player instance from scene"""
	var player_scene = load(player_path)
	if player_scene == null:
		GlobalVariables.d_error("Error: cannot load player scene from " + player_path, "LEVEL_MANAGEMENT")
		return null
		
	return player_scene.instantiate()

func setup_player_instance(player_instance: Node) -> void:
	"""Setup player instance with position and properties"""
	var world_position = tilemap.map_to_local(LevelManager.player_spawn_position)
	player_instance.position = world_position
	player_instance.current_grid_position = LevelManager.player_spawn_position
	player_instance.tilemap = tilemap

#endregion
