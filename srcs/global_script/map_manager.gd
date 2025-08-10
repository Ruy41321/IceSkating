extends Node

#region MAP STATE

var map_grid: Array
var map_grid_backup: Array = []  # Backup for map reset after match

#endregion

#region MAP GENERATION

var map_generator: Map_gen = Map_gen.new()

# Threading variables
var generation_thread: Thread
var generation_mutex: Mutex
var generation_completed: bool = false
var generation_result: Dictionary = {}
var generation_error: String = ""

# Threading support cache
var threading_support_cached: bool = false
var threading_support_result: bool = false

#endregion

#region TILE CONFIGURATION

# Tile mappings are now centralized in GlobalVariables
# Access via GlobalVariables.tile_mapping and GlobalVariables.tile_id_mapping

#endregion

#region MAP GRID MANAGEMENT

func get_map_grid() -> Array:
	"""Get current map grid"""
	return map_grid

func set_map_grid(grid: Array) -> void:
	"""Set map grid and create backup"""
	map_grid = grid
	map_grid_backup = map_grid.duplicate()  # Backup for match reset

func reset_map_grid() -> void:
	"""Reset map grid to backup state"""
	map_grid = map_grid_backup.duplicate()

#endregion

#region MAP DATA LOADING

func get_map_data(map_file_path: String) -> Dictionary:
	"""
	Load map data from file.
	Supports both maps with complete metadata and maps with grid only.
	
	Args:
		map_file_path: Path to the map file to load
		
	Returns:
		Dictionary containing width, height, difficulty, min_moves, total_moves, grid
	"""
	if map_file_path == "":
		push_error("Cannot find map file")
		return {}

	var file = FileAccess.open(map_file_path, FileAccess.READ)
	if not file:
		push_error("Cannot open map file: " + map_file_path)
		return {}
	
	var map_data = create_default_map_data()
	var grid_lines = []
	var reading_grid = false
		
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if should_skip_line(line):
			continue
		
		if is_metadata_line(line) and not reading_grid:
			process_metadata_line(line, map_data)
			continue
		
		if is_grid_line(line):
			reading_grid = true
			grid_lines.append(line)
		
	file.close()
	
	finalize_map_data(map_data, grid_lines)
	return map_data

func create_default_map_data() -> Dictionary:
	"""Create default map data structure"""
	return {
		"width": 0,
		"height": 0,
		"difficulty": 0,
		"min_moves": 0,
		"total_moves": 0,
		"grid": []
	}

func should_skip_line(line: String) -> bool:
	"""Check if line should be skipped during parsing"""
	return line.is_empty() or line.begins_with("#")

func is_metadata_line(line: String) -> bool:
	"""Check if line contains metadata"""
	return line.find("=") != -1

func process_metadata_line(line: String, map_data: Dictionary) -> void:
	"""Process a metadata line and update map data"""
	var parts = line.split("=", false, 1)
	if parts.size() != 2:
		return
		
	var key = parts[0].strip_edges()
	var value_str = parts[1].strip_edges()
	
	match key:
		"width":
			map_data.width = int(value_str)
		"height":
			map_data.height = int(value_str)
		"difficulty":
			map_data.difficulty = int(value_str)
		"min_moves":
			map_data.min_moves = int(value_str)
		"total_moves":
			map_data.total_moves = int(value_str)

func finalize_map_data(map_data: Dictionary, grid_lines: Array) -> void:
	"""Finalize map data with grid information"""
	if grid_lines.size() > 0:
		map_data.grid = grid_lines
		
		# Calculate dimensions from grid if not specified
		if map_data.width == 0:
			map_data.width = grid_lines[0].length()
		if map_data.height == 0:
			map_data.height = grid_lines.size()
		
		# Verify dimension consistency
		validate_map_dimensions(map_data, grid_lines)

func validate_map_dimensions(map_data: Dictionary, grid_lines: Array) -> void:
	"""Validate and correct map dimensions"""
	var actual_width = grid_lines[0].length()
	var actual_height = grid_lines.size()
	
	if map_data.width != actual_width or map_data.height != actual_height:
		GlobalVariables.d_warning("Warning: Specified dimensions don't match grid", "MAP_MANAGEMENT")
		map_data.width = actual_width
		map_data.height = actual_height

func is_grid_line(line: String) -> bool:
	"""
	Check if a line contains valid map grid characters.
	Valid characters: M, G, T, I, E, D, 1, 2, 3, 4
	
	Args:
		line: Line to verify
		
	Returns:
		true if line contains only valid map characters
	"""
	if line.is_empty():
		return false
		
	var valid_chars = GlobalVariables.tile_mapping.keys()
	for ch in line:
		if not ch in valid_chars:
			return false
		
	return true

# Renamed from _is_grid_line for consistency
func _is_grid_line(line: String) -> bool:
	"""Legacy function - use is_grid_line instead"""
	return is_grid_line(line)

#endregion

#region MAP FILE MANAGEMENT

func get_file_path(user1_id: String, user2_id: String, difficulty: String) -> Dictionary:
	"""
	Get map file path for given users and difficulty.
	Tries to get an uncompleted map from database, generates new one if needed.
	
	Args:
		user1_id: First user ID
		user2_id: Second user ID  
		difficulty: Map difficulty level
		
	Returns:
		Dictionary with file_path, name, and id
	"""
	var base_path = "user://maps/"
	var map_info = await get_or_create_map(user1_id, user2_id, difficulty)
	
	if map_info.is_empty():
		return {}
	
	update_map_statistics(map_info.name, map_info.id)
	
	return {
		"file_path": base_path + map_info.name + ".map",
		"name": map_info.name,
		"id": map_info.id,
	}

func get_or_create_map(user1_id: String, user2_id: String, difficulty: String) -> Dictionary:
	"""Get existing map or create new one"""
	var map_data = await GameAPI.get_uncompleted_map(int(difficulty), int(user1_id), int(user2_id))
	var map_name = ""
	var map_id = -1
	
	if map_data.size() == 2:
		map_name = map_data[0]
		map_id = map_data[1]
	
	if map_name == "":
		var new_map_info = await create_new_map(difficulty)
		map_name = new_map_info.name
		map_id = new_map_info.id
	
	return {"name": map_name, "id": map_id}

func create_new_map(difficulty: String) -> Dictionary:
	"""Create a new map with given difficulty"""
	var map_name = generate_map_name()
	await generate_map_threaded(map_name, difficulty)
	
	if generation_error != "":
		GlobalVariables.d_error("Error during map generation: " + str(generation_error), "MAP_GENERATION")
		map_name = get_fallback_map_name()
		if map_name == "":
			push_error("Cannot generate or find a valid emergency map")
			return {}
		return {"name": map_name, "id": -1}
	
	var result = await GameAPI.create_map(map_name, int(difficulty))
	if result.get("success", false):
		return {"name": map_name, "id": result.get("map_id", -1)}
	else:
		push_error("Error inserting map in database: " + result.get("error", ""))
		return {"name": map_name, "id": -1}

func update_map_statistics(map_name: String, map_id: int) -> void:
	"""Update map usage statistics"""
	GameAPI.update_map_stats(map_name, map_id, false)

#endregion

#region MAP GENERATION THREADING

func generate_map_threaded(map_name: String, difficulty: String) -> int:
	"""
	Generate a map using a separate thread.
	
	Args:
		map_name: Name for the generated map
		difficulty: Difficulty level
		
	Returns:
		0 on success, 1 on failure
	"""
	# Check if threading is actually supported
	if not await _is_threading_supported():
		GlobalVariables.d_info("Threading not supported, using direct generation", "MAP_GENERATION")
		return await _generate_map_direct(map_name, difficulty)
	
	GlobalVariables.d_info("Threading supported, using threaded generation", "MAP_GENERATION")
	initialize_threading_variables()
	
	# Start generation thread
	generation_thread.start(_generate_map_thread_func.bind(map_name, difficulty))
	
	# Monitor progress and cleanup
	var result = await _monitor_generation_progress()
	
	cleanup_threading_resources()
	
	return result

func _is_threading_supported() -> bool:
	"""Check if threading is supported in the current environment"""
	
	# Return cached result if we already tested
	if threading_support_cached:
		GlobalVariables.d_debug("Using cached threading support result: " + str(threading_support_result), "MAP_GENERATION")
		return threading_support_result
	
	GlobalVariables.d_debug("Testing threading capability...", "MAP_GENERATION")
	
	# First, check if we're in a web environment
	if OS.has_feature("web"):
		GlobalVariables.d_debug("Web environment detected - performing thread capability test", "MAP_GENERATION")
		
		# In web environments, try to test if threading actually works
		var test_thread = Thread.new()
		var result = await _test_thread_capability(test_thread)
		
		# Cache and return the result
		threading_support_result = result
		threading_support_cached = true
		
		if result:
			GlobalVariables.d_debug("Threading is supported in this web environment", "MAP_GENERATION")
		else:
			GlobalVariables.d_debug("Threading is not properly supported in this web environment", "MAP_GENERATION")
		
		return result
	else:
		# On desktop/mobile, assume threading works
		GlobalVariables.d_debug("Desktop/mobile environment - threading should be supported", "MAP_GENERATION")
		threading_support_result = true
		threading_support_cached = true
		return true

class ThreadTestResult:
	var completed = false
	var mutex: Mutex
	
	func _init():
		mutex = Mutex.new()
	
	func set_completed():
		mutex.lock()
		completed = true
		mutex.unlock()
	
	func is_completed() -> bool:
		mutex.lock()
		var result = completed
		mutex.unlock()
		return result

func _test_thread_capability(test_thread: Thread) -> bool:
	"""Test if we can actually use threads by trying to start one"""
	
	# Create a shared result object
	var test_result = ThreadTestResult.new()
	
	# Create a test function that sets our flag
	var test_callable = func():
		test_result.set_completed()
	
	# Try to start the thread
	var error = test_thread.start(test_callable)
	if error != OK:
		GlobalVariables.d_debug("Thread start failed with error code: " + str(error), "MAP_GENERATION")
		return false
	
	# Wait for the operation with a timeout
	var timeout_counter = 0
	while timeout_counter < 10:  # Wait up to 1 second
		await get_tree().create_timer(0.1).timeout
		
		if test_result.is_completed():
			break
			
		timeout_counter += 1
	
	# Clean up the thread
	test_thread.wait_to_finish()
	
	# Check if the test actually completed
	var success = test_result.is_completed()
	
	if success:
		GlobalVariables.d_debug("Thread capability test completed successfully", "MAP_GENERATION")
	else:
		GlobalVariables.d_debug("Thread test timed out - threading may not be fully supported", "MAP_GENERATION")
	
	return success

func _generate_map_direct(map_name: String, difficulty: String) -> int:
	"""
	Generate a map directly without threading (browser-safe).
	
	Args:
		map_name: Name for the generated map
		difficulty: Difficulty level
		
	Returns:
		0 on success, 1 on failure
	"""
	const MAX_ATTEMPTS = 3
	var success = false
	
	for attempt in range(MAX_ATTEMPTS):
		var exit_code = await map_generator.generate_map(map_name, difficulty)
		
		if exit_code == 0:
			var generated_map_path = "user://maps/" + map_name + ".map"
			
			if is_valid_map(generated_map_path):
				success = true
				break
		
		# Wait before retry
		if attempt < MAX_ATTEMPTS - 1:
			await get_tree().create_timer((attempt + 1) * 0.5).timeout
	
	if success:
		return 0
	else:
		return 1

func initialize_threading_variables() -> void:
	"""Initialize threading variables for map generation"""
	generation_thread = Thread.new()
	generation_mutex = Mutex.new()
	generation_completed = false
	generation_result = {}
	generation_error = ""

func cleanup_threading_resources() -> void:
	"""Clean up threading resources after generation"""
	if generation_thread:
		generation_thread.wait_to_finish()
		generation_thread = null
	generation_mutex = null

func _generate_map_thread_func(map_name: String, difficulty: String) -> void:
	"""Thread function for map generation with retry logic"""
	const MAX_ATTEMPTS = 3
	var success = false
	
	for attempt in range(MAX_ATTEMPTS):
		# Note: Can't use await in threads, so we use the synchronous version
		var exit_code = map_generator.generate_map_sync(map_name, difficulty)
		
		if exit_code == 0:
			var generated_map_path = "user://maps/" + map_name + ".map"
			
			if is_valid_map(generated_map_path):
				success = true
				break
		
		# Wait before retry (exponential backoff)
		if attempt < MAX_ATTEMPTS - 1:
			OS.delay_msec(int((attempt + 1) * 500))
	
	# Set thread result
	update_generation_result(success)

func update_generation_result(success: bool) -> void:
	"""Update generation result in thread-safe manner"""
	generation_mutex.lock()
	generation_completed = true
	if success:
		generation_result = {"success": true}
	else:
		generation_error = "Unable to generate a valid map after multiple attempts"
	generation_mutex.unlock()

func _monitor_generation_progress() -> int:
	"""Monitor map generation progress and return result"""
	while not is_generation_completed():
		await get_tree().process_frame
		await get_tree().create_timer(0.1).timeout
	
	return get_generation_error_code()

func is_generation_completed() -> bool:
	"""Check if generation is completed in thread-safe manner"""
	generation_mutex.lock()
	var completed = generation_completed
	generation_mutex.unlock()
	return completed

func get_generation_error_code() -> int:
	"""Get generation error code in thread-safe manner"""
	generation_mutex.lock()
	var error = generation_error
	generation_mutex.unlock()
	
	if error != "":
		GlobalVariables.d_error("Map generation error: " + str(error), "MAP_GENERATION")
		return 1
	return 0

#endregion

#region MAP VALIDATION

func is_valid_map(file_path: String) -> bool:
	"""
	Validate if a map file is valid and playable.
	
	Args:
		file_path: Path to the map file to validate
		
	Returns:
		true if map is valid, false otherwise
	"""
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		GlobalVariables.d_error("Cannot open map file for validation: " + str(file_path), "MAP_MANAGEMENT")
		return false
	
	var validation_data = initialize_validation_data()
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		process_validation_line(line, validation_data)
	
	file.close()
	return validate_map_requirements(validation_data, file_path)

func initialize_validation_data() -> Dictionary:
	"""Initialize data structure for map validation"""
	return {
		"has_spawn": false,
		"has_exit": false,
		"map_lines": 0
	}

func process_validation_line(line: String, validation_data: Dictionary) -> void:
	"""Process a single line during map validation"""
	# Skip metadata and empty lines
	if line.length() == 0 or line.begins_with("#") or line.contains("="):
		return
	
	validation_data.map_lines += 1
	
	# Check for valid characters and required elements
	for ch in line:
		if not GlobalVariables.tile_mapping.has(ch):
			validation_data.invalid_char = ch
			return
		
		if ch == "I":
			validation_data.has_spawn = true
		elif ch == "E":
			validation_data.has_exit = true

func validate_map_requirements(validation_data: Dictionary, file_path: String) -> bool:
	"""Validate that map meets all requirements"""
	if validation_data.has("invalid_char"):
		GlobalVariables.d_error("Invalid character '" + str(validation_data.invalid_char) + "' found in " + str(file_path), "MAP_MANAGEMENT")
		return false
	
	if validation_data.map_lines < 3:
		GlobalVariables.d_error("Map too small: " + str(file_path), "MAP_MANAGEMENT")
		return false
	
	if not validation_data.has_spawn:
		GlobalVariables.d_error("Map missing spawn point (I): " + str(file_path), "MAP_MANAGEMENT")
		return false
	
	if not validation_data.has_exit:
		GlobalVariables.d_error("Map missing exit point (E): " + str(file_path), "MAP_MANAGEMENT")
		return false
	
	return true

#endregion

#region FALLBACK MAP MANAGEMENT

func get_fallback_map_name() -> String:
	"""
	Get a fallback map when generation fails.
	Searches user://maps/ and res://maps/ for valid maps.
	
	Returns:
		Name of a valid fallback map, or creates emergency map
	"""
	var valid_maps = find_valid_maps_in_directories()
	
	if valid_maps.size() > 0:
		return select_random_fallback_map(valid_maps)
	else:
		GlobalVariables.d_warning("No valid maps found in user:// or res://", "MAP_MANAGEMENT")
		return create_emergency_map()

func find_valid_maps_in_directories() -> Array:
	"""Find all valid maps in user:// and res:// directories"""
	var valid_maps = []
	
	# Search in user://maps/
	find_valid_maps_in_directory("user://maps/", valid_maps)
	
	# Search in res://maps/
	find_valid_maps_in_directory("res://maps/", valid_maps)
	
	return valid_maps

func find_valid_maps_in_directory(directory_path: String, valid_maps: Array) -> void:
	"""Find valid maps in a specific directory"""
	var dir = DirAccess.open(directory_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if is_map_file_candidate(file_name, valid_maps):
			var file_path = directory_path + file_name
			if is_valid_map(file_path):
				valid_maps.append(file_name)
				GlobalVariables.d_debug("Valid map found in " + str(directory_path) + ": " + str(file_name), "MAP_MANAGEMENT")
			else:
				GlobalVariables.d_warning("Invalid map ignored in " + str(directory_path) + ": " + str(file_name), "MAP_MANAGEMENT")
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func is_map_file_candidate(file_name: String, existing_maps: Array) -> bool:
	"""Check if file is a candidate for fallback map"""
	return (file_name.ends_with(".map") and 
			file_name != "emergency.map" and 
			not existing_maps.has(file_name))

func select_random_fallback_map(valid_maps: Array) -> String:
	"""Select a random map from valid maps list"""
	var random_index = randi() % valid_maps.size()
	var map_name = valid_maps[random_index]
	map_name = map_name.substr(0, map_name.length() - 4)  # Remove .map extension
	GlobalVariables.d_info("Selected random fallback map: " + str(map_name), "MAP_MANAGEMENT")
	return map_name

func create_emergency_map() -> String:
	"""
	Create an emergency map when no valid maps are found.
	
	Returns:
		Name of the emergency map, or empty string on failure
	"""
	const EMERGENCY_MAP_NAME = "emergency"
	var emergency_content = create_emergency_map_content()
	
	var emergency_file = FileAccess.open("user://maps/emergency.map", FileAccess.WRITE)
	if emergency_file != null:
		emergency_file.store_string(emergency_content)
		emergency_file.close()
		GlobalVariables.d_info("Emergency map created", "MAP_GENERATION")
		return EMERGENCY_MAP_NAME
	else:
		GlobalVariables.d_error("Error: Unable to create emergency map", "MAP_GENERATION")
		return ""

func create_emergency_map_content() -> String:
	"""Create content for emergency map"""
	return """# Emergency map
width=9
height=5
difficulty=1
min_moves=5
total_moves=10
MMMMMMMMM
MIGGGGGEM
MGGGGGGGM
MGGGGGGGM
MMMMMMMMM"""

#endregion

#region MAP NAME GENERATION

func generate_map_name() -> String:
	"""
	Generate a unique map name with thematic words.
	Checks that the name doesn't already exist in user://maps/
	
	Returns:
		Generated map name (without extension)
	"""
	ensure_maps_directory_exists()
	
	var name_components = get_name_components()
	var rng = create_randomizer()
	
	# Try up to 100 combinations
	for attempt in range(100):
		var map_name = generate_thematic_name(name_components, rng)
		
		if not FileAccess.file_exists("user://maps/" + map_name + ".map"):
			return map_name
	
	# Fallback with timestamp if all combinations are taken
	return generate_timestamp_fallback_name()

func ensure_maps_directory_exists() -> void:
	"""Ensure the maps directory exists"""
	const MAPS_DIR = "user://maps/"
	if not DirAccess.dir_exists_absolute(MAPS_DIR):
		DirAccess.open("user://").make_dir_recursive("maps")

func get_name_components() -> Dictionary:
	"""Get name components for map generation"""
	return {
		"prefixes": [
			"frozen", "icy", "crystal", "arctic", "polar", "winter", 
			"frost", "snow", "glacier", "diamond", "chilly", "cold"
		],
		"suffixes": [
			"maze", "palace", "cavern", "fortress", "arena", "course",
			"puzzle", "challenge", "adventure", "spiral", "drift", "temple"
		]
	}

func create_randomizer() -> RandomNumberGenerator:
	"""Create and initialize random number generator"""
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	return rng

func generate_thematic_name(name_components: Dictionary, rng: RandomNumberGenerator) -> String:
	"""Generate a thematic map name"""
	var prefix = name_components.prefixes[rng.randi() % name_components.prefixes.size()]
	var suffix = name_components.suffixes[rng.randi() % name_components.suffixes.size()]
	var number = rng.randi_range(1, 999)
	
	return prefix + "_" + suffix + "_" + str(number).pad_zeros(3)

func generate_timestamp_fallback_name() -> String:
	"""Generate fallback name using timestamp"""
	var timestamp = Time.get_unix_time_from_system()
	return "map_" + str(timestamp)

#endregion
