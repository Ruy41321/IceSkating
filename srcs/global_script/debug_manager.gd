extends Node

#region DEBUG CONFIGURATION

# Debug levels
enum Level {
	NONE = 0,      # No debug output
	ERROR = 1,     # Only critical errors
	WARNING = 2,   # Errors and warnings
	INFO = 3,      # General information
	DEBUG = 4,     # Detailed debugging info
	VERBOSE = 5    # Everything including detailed traces
}

# Current debug level - change this to control what gets printed
var current_debug_level: Level = Level.WARNING

# Debug categories - enable/disable specific categories
var debug_categories = {
	"PLAYER_INPUT": false,      # Player input and movement
	"MENU": false,              # Menu and UI interactions
	"NETWORK": false,           # Multiplayer networking
	"MAP_GENERATION": false,    # Map loading and generation
	"MAP_MANAGEMENT": false,    # Map management and operations
	"GAME_STATE": false,        # Game state changes
	"ANIMATION": false,         # Animation system
	"LEVEL_MANAGEMENT": false,  # Level transitions
	"AUTHENTICATION": false,    # User authentication
	"ROOM_MANAGEMENT": false,   # Room creation/joining
	"RANKED_SYSTEM": false,     # Ranked mode system
	"PLAYER_MANAGEMENT": false, # Player spawning and management
	"GENERAL": true,            # General debug messages
	"AUDIO": false              # Audio system messages
}

#endregion

#region INITIALIZATION

func _ready() -> void:
	"""Initialize debug manager with preset configuration"""
	_apply_debug_config()
	info("DebugManager initialized", "GENERAL")

func _apply_debug_config() -> void:
	"""Apply debug configuration from DebugConfig"""
	# Load the debug config script
	var debug_config = load("res://global_script/debug_config.gd")
	var config_settings = debug_config.get_preset_settings(debug_config.CURRENT_PRESET) if not "--server" in OS.get_cmdline_args() \
																							and not LevelManager.use_local_server \
					else debug_config.get_preset_settings(debug_config.DebugPreset.HEADLESS_SERVER)

	# Set debug level
	current_debug_level = config_settings.level
	
	# Configure categories
	var categories = config_settings.categories
	for category in debug_categories:
		debug_categories[category] = categories.get(category, false)
	
	# Print configuration status
	info("Debug configuration applied - Preset: " + str(debug_config.CURRENT_PRESET), "GENERAL")

#endregion

#region DEBUG FUNCTIONS

func debug_print(message: String, level: Level = Level.DEBUG, category: String = "GENERAL") -> void:
	"""Print debug message if level and category are enabled"""
	# Check if debug level is sufficient
	if int(level) > int(current_debug_level):
		return
		
	# Check if category is enabled
	if not debug_categories.get(category, false):
		return
	
	# Format and print message
	var level_str = _get_level_string(level)
	var timestamp = Time.get_datetime_string_from_system()
	print("[%s][%s][%s] %s" % [timestamp, level_str, category, message])

func error(message: String, category: String = "GENERAL") -> void:
	"""Print error message"""
	debug_print("ERROR: " + message, Level.ERROR, category)

func warning(message: String, category: String = "GENERAL") -> void:
	"""Print warning message"""
	debug_print("WARNING: " + message, Level.WARNING, category)

func info(message: String, category: String = "GENERAL") -> void:
	"""Print info message"""
	debug_print("INFO: " + message, Level.INFO, category)

func debug(message: String, category: String = "GENERAL") -> void:
	"""Print debug message"""
	debug_print("DEBUG: " + message, Level.DEBUG, category)

func verbose(message: String, category: String = "GENERAL") -> void:
	"""Print verbose debug message"""
	debug_print("VERBOSE: " + message, Level.VERBOSE, category)

#endregion

#region UTILITY FUNCTIONS

func _get_level_string(level: Level) -> String:
	"""Convert debug level enum to string"""
	match level:
		Level.ERROR:
			return "ERROR"
		Level.WARNING:
			return "WARN"
		Level.INFO:
			return "INFO"
		Level.DEBUG:
			return "DEBUG"
		Level.VERBOSE:
			return "VERBOSE"
		_:
			return "NONE"

#endregion

#region CONFIGURATION FUNCTIONS

func enable_category(category: String) -> void:
	"""Enable debugging for a specific category"""
	if debug_categories.has(category):
		debug_categories[category] = true
		info("Debug enabled for category: " + category, "GENERAL")

func disable_category(category: String) -> void:
	"""Disable debugging for a specific category"""
	if debug_categories.has(category):
		debug_categories[category] = false
		info("Debug disabled for category: " + category, "GENERAL")

func set_level(level: Level) -> void:
	"""Set the global debug level"""
	current_debug_level = level
	info("Debug level set to: " + _get_level_string(level), "GENERAL")

func enable_all_categories() -> void:
	"""Enable all debug categories - useful for debugging"""
	for category in debug_categories:
		debug_categories[category] = true
	info("All debug categories enabled", "GENERAL")

func disable_all_categories() -> void:
	"""Disable all debug categories - clean output"""
	for category in debug_categories:
		debug_categories[category] = false
	info("All debug categories disabled", "GENERAL")

#endregion

#region DEVELOPMENT HELPERS

func print_debug_status() -> void:
	"""Print current debug configuration"""
	print("\n=== DEBUG CONFIGURATION ===")
	print("Current Level: ", _get_level_string(current_debug_level))
	print("Enabled Categories:")
	for category in debug_categories:
		if debug_categories[category]:
			print("  - ", category)
	print("============================\n")

#endregion
