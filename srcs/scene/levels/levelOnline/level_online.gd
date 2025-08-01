class_name LevelOnline
extends Node2D

#region SCENE REFERENCES

@onready var tilemap: TileMapLayer = $BaseTileMap

#endregion

#region CONFIGURATION

var player_path: String = GlobalVariables.player_online_path
var player_spawn_position: Vector2i = Vector2i(-1, -1)

#endregion

#region INITIALIZATION

func _ready() -> void:
	"""Initialize the multiplayer level"""
	# Start background music for level
	AudioManager.play_background_music("level")
	
	LevelManager.current_moves_count = 0
	if OK == load_map_from_grid(MapManager.get_map_grid()):
		spawn_player(player_spawn_position)

#endregion

#region MAP LOADING

func load_map_from_grid(grid: Array) -> int:
	"""
	Load map from grid data and populate the tilemap.
	
	Args:
		grid: 2D array representing the map grid
		
	Returns:
		0 on success, 1 on error
	"""
	if grid.is_empty():
		GlobalVariables.d_error("Error: empty grid", "MAP_MANAGEMENT")
		return 1
		
	GlobalVariables.d_debug("Loading map from grid...", "MAP_MANAGEMENT")
	GlobalVariables.d_debug("Grid dimensions: " + str(grid[0].length()) + "x" + str(grid.size()), "MAP_MANAGEMENT")
		
	process_grid_data(grid)
		
	GlobalVariables.d_info("Map loaded successfully from grid", "MAP_MANAGEMENT")
	return 0

func process_grid_data(grid: Array) -> void:
	"""Process each row and column of the grid data"""
	for y in range(grid.size()):
		var line = grid[y]
		process_grid_row(line, y)

func process_grid_row(line: String, y: int) -> void:
	"""Process a single row of the grid"""
	for x in range(line.length()):
		var ch = line[x]
		process_grid_cell(ch, x, y)

func process_grid_cell(ch: String, x: int, y: int) -> void:
	"""Process a single cell in the grid"""
	if GlobalVariables.tile_mapping.has(ch):
		# Apply border tile mapping if position is on the edge
		ch = get_border_tile_type(ch, x, y)
		
		var atlas_coords = GlobalVariables.tile_mapping[ch]
		var tile_id = GlobalVariables.tile_id_mapping[ch]
		set_tile_at_position(x, y, tile_id, atlas_coords)
		
		# Store player spawn position
		if ch == "I":
			player_spawn_position = Vector2i(x, y)
	else:
		GlobalVariables.d_warning("Unrecognized character in grid: '" + str(ch) + "' at position (" + str(x) + "," + str(y) + ")", "MAP_MANAGEMENT")

func get_border_tile_type(original_ch: String, x: int, y: int) -> String:
	"""
	Determine the appropriate border tile type based on position.
	Returns the original character if not on a border.
	"""
	var grid = MapManager.get_map_grid()
	var max_x = grid[0].length() - 1
	var max_y = grid.size() - 1
	
	# Check if position is on any border
	var is_left = x == 0
	var is_right = x == max_x
	var is_top = y == 0
	var is_bottom = y == max_y
	
	# Return original character if not on border
	if not (is_left or is_right or is_top or is_bottom):
		return original_ch
	
	# Map border positions to tile types using a lookup table
	var border_mapping = {
		# Corners
		[true, false, true, false]: "PTL",   # Top-left
		[true, false, false, true]: "PTR",   # Bottom-left  
		[false, true, true, false]: "PBL",   # Top-right
		[false, true, false, true]: "PBR",   # Bottom-right
		# Edges
		[true, false, false, false]: "PTM",  # Left edge
		[false, true, false, false]: "PBM",  # Right edge
		[false, false, true, false]: "PL",   # Top edge
		[false, false, false, true]: "PR"    # Bottom edge
	}
	
	var position_key = [is_left, is_right, is_top, is_bottom]
	return border_mapping.get(position_key, original_ch)

#endregion

#region TILE MANAGEMENT

func set_tile_at_position(x: int, y: int, source_id: int, atlas_coords: Vector2i) -> void:
	"""Helper function to set a tile at the specified position"""
	tilemap.set_cell(Vector2i(x, y), source_id, atlas_coords)

#endregion

#region PLAYER SPAWNING

func spawn_player(new_player_spawn_pos: Vector2i, player_id: int = ClientManager.my_peer_id) -> void:
	"""
	Spawn a player at the specified position.
	
	Args:
		new_player_spawn_pos: Grid position where player should spawn
		player_id: ID of the player to spawn
	"""
	if not validate_spawn_position(new_player_spawn_pos):
		return
		
	var player_instance = create_player_instance()
	if player_instance == null:
		return
		
	setup_multiplayer_player_instance(player_instance, new_player_spawn_pos, player_id)
	add_child(player_instance)
	
	LevelManager.player_list.append(player_instance)
	
	if player_instance.my_id == ClientManager.my_peer_id:
		ClientManager.notify_player_spawn(new_player_spawn_pos)
	
	GlobalVariables.d_debug("Player spawned at grid position: " + str(new_player_spawn_pos) + " (world: " + str(player_instance.position) + ")", "PLAYER_MANAGEMENT")

func validate_spawn_position(spawn_pos: Vector2i) -> bool:
	"""Validate that the spawn position is valid"""
	if spawn_pos == Vector2i(-1, -1):
		GlobalVariables.d_error("Error: player spawn position not found!", "PLAYER_MANAGEMENT")
		return false
	return true

func create_player_instance() -> Node:
	"""Create player instance from scene"""
	var player_scene = load(player_path)
	if player_scene == null:
		GlobalVariables.d_error("Error: cannot load player scene from " + str(player_path), "PLAYER_MANAGEMENT")
		return null
		
	return player_scene.instantiate()

func setup_multiplayer_player_instance(player_instance: Node, spawn_pos: Vector2i, player_id: int) -> void:
	"""Setup multiplayer player instance with position and properties"""
	var world_position = tilemap.map_to_local(spawn_pos)
	player_instance.position = world_position
	player_instance.current_grid_position = spawn_pos
	player_instance.grid_position_for_collision = spawn_pos
	player_instance.my_id = player_id
	player_instance.tilemap = tilemap
	
	if player_id == ClientManager.my_peer_id:
		player_instance.is_local_player = true

#endregion
