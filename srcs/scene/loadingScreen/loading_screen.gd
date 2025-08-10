extends Control

var test_custom_map: bool = false  # Flag to test custom map loading

func _ready() -> void:
	GlobalVariables.d_info("Loading screen started...", "LEVEL_MANAGEMENT")
	await process_map_loading()

func process_map_loading() -> void:
	"""Process map loading and scene transition"""
	var difficulty: String = LevelManager.get_offline_difficulty()
	var map_name = LevelManager.get_to_play_map_name()
	
	GlobalVariables.d_debug("Processing map: " + map_name + " with difficulty: " + str(difficulty), "MAP_GENERATION")
	
	var file_path: String = await determine_map_file_path(map_name, difficulty)
	
	if file_path.is_empty():
		GlobalVariables.d_error("Error: Failed to determine map file path", "MAP_GENERATION")
		GlobalVariables.map_gen_error = true
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)
		return
	
	var map_data = MapManager.get_map_data(file_path)
	if map_data == null:
		GlobalVariables.map_gen_error = true
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)
		return
	
	var grid = map_data.get("grid", [])
	if grid.is_empty():
		GlobalVariables.map_gen_error = true
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)
		return
	
	MapManager.set_map_grid(grid)
	
	if not ResourceLoader.exists(GlobalVariables.tilemap_path):
		GlobalVariables.map_gen_error = true
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)
		return
	
	var tilemap_resource = load(GlobalVariables.tilemap_path)
	if tilemap_resource == null:
		GlobalVariables.map_gen_error = true
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)
		return
	
	LevelManager.tilemap = tilemap_resource.instantiate()
	if LevelManager.tilemap == null:
		GlobalVariables.map_gen_error = true
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)
		return
	
	load_map_from_grid(MapManager.get_map_grid())

	# Use call_deferred to ensure proper scene transition
	get_tree().call_deferred("change_scene_to_file", GlobalVariables.level_offline_path)#region MAP LOADING

func load_map_from_grid(grid: Array) -> int:
	"""
	Load map from grid data and populate the tilemap.
	
	Args:
		grid: 2D array representing the map grid
		
	Returns:
		0 on success, 1 on error
	"""
	if grid.is_empty():
		GlobalVariables.d_error("Error: empty grid", "MAP_GENERATION")
		return 1
		
	GlobalVariables.d_debug("Loading map from grid...", "MAP_GENERATION")
	GlobalVariables.d_debug("Grid dimensions: " + str(grid[0].length()) + "x" + str(grid.size()), "MAP_GENERATION")
	
	process_grid_data(grid)
		
	GlobalVariables.d_info("Map loaded successfully from grid", "MAP_GENERATION")
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
			LevelManager.player_spawn_position = Vector2i(x, y)
	else:
		GlobalVariables.d_warning("Unrecognized character in grid: '" + ch + "' at position (" + str(x) + "," + str(y) + ")", "MAP_GENERATION")

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
	LevelManager.tilemap.set_cell(Vector2i(x, y), source_id, atlas_coords)

#endregion

func determine_map_file_path(map_name: String, difficulty: String) -> String:
	"""Determine the file path for the map based on configuration"""
	if test_custom_map:
		return handle_test_custom_map(map_name)
	elif LevelManager.new_map:
		LevelManager.new_map = false  # Reset for next time
		return await handle_new_map_generation(map_name, difficulty)
	else:
		return await handle_existing_or_generate_map(map_name, difficulty)

func handle_test_custom_map(map_name: String) -> String:
	"""Handle test custom map loading"""
	Map_gen.new().test_map(map_name)
	return "res://maps/" + map_name + ".map"

func handle_new_map_generation(map_name: String, difficulty: String) -> String:
	"""Generate a new map, overwriting if it exists"""
	await MapManager.generate_map_threaded(map_name, difficulty)
	return "user://maps/" + map_name + ".map"

func handle_existing_or_generate_map(map_name: String, difficulty: String) -> String:
	"""Check if map exists, otherwise generate it"""
	var user_map_path = "user://maps/" + map_name + ".map"
	var res_map_path = "res://maps/" + map_name + ".map"
	
	if FileAccess.file_exists(user_map_path):
		GlobalVariables.d_debug("Map '" + map_name + "' found in user://maps/, loading directly...", "MAP_GENERATION")
		return user_map_path
	elif FileAccess.file_exists(res_map_path):
		GlobalVariables.d_debug("Map '" + map_name + "' found in res://maps/, loading directly...", "MAP_GENERATION")
		return res_map_path
	else:
		GlobalVariables.d_info("Map '" + map_name + "' not found, generating...", "MAP_GENERATION")
		await MapManager.generate_map_threaded(map_name, difficulty)
		return user_map_path
