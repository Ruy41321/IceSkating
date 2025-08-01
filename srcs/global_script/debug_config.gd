# Debug Configuration
# This file allows you to quickly configure debug settings for development

extends Resource
class_name DebugConfig

#region DEBUG PRESETS

# Quick preset configurations
enum DebugPreset {
	RELEASE,        # No debug output (production)
	BASIC,          # Only errors and warnings
	DEVELOPMENT,    # Common development debugging
	FULL_DEBUG,     # Everything enabled for deep debugging
	HEADLESS_SERVER, # Optimized for headless server debugging
	CUSTOM          # Use custom settings below
}

#endregion

#region DEBUG LEVELS (matching DebugManager.Level)

enum Level {
	NONE = 0,      # No debug output
	ERROR = 1,     # Only critical errors
	WARNING = 2,   # Errors and warnings
	INFO = 3,      # General information
	DEBUG = 4,     # Detailed debugging info
	VERBOSE = 5    # Everything including detailed traces
}

#endregion

#region CONFIGURATION

# Choose your debug preset here
const CURRENT_PRESET: DebugPreset = DebugPreset.CUSTOM

# Custom settings (used when CURRENT_PRESET is CUSTOM)
const CUSTOM_DEBUG_LEVEL = Level.INFO
const CUSTOM_CATEGORIES = {
	"PLAYER_INPUT": true,       # Player input and movement
	"MENU": false,               # Menu and UI interactions
	"NETWORK": true,             # Multiplayer networking
	"MAP_GENERATION": false,     # Map loading and generation
	"MAP_MANAGEMENT": false,     # Map management and operations
	"GAME_STATE": true,          # Game state changes
	"ANIMATION": true,           # Animation system
	"LEVEL_MANAGEMENT": false,   # Level transitions
	"AUTHENTICATION": true,      # User authentication
	"ROOM_MANAGEMENT": true,     # Room creation/joining
	"RANKED_SYSTEM": true,       # Ranked mode system
	"PLAYER_MANAGEMENT": false,  # Player spawning and management
	"GENERAL": true,             # General debug messages
	"AUDIO": true                # Audio system messages
}

#endregion

#region PRESET DEFINITIONS

static func get_preset_settings(preset: DebugPreset) -> Dictionary:
	"""Get debug settings for a given preset"""
	match preset:
		DebugPreset.RELEASE:
			return {
				"level": Level.NONE,
				"categories": {}  # All disabled
			}
		
		DebugPreset.BASIC:
			return {
				"level": Level.WARNING,
				"categories": {
					"GENERAL": true,
					"PLAYER_INPUT": false,
					"MENU": false,
					"NETWORK": false,
					"MAP_GENERATION": false,
					"MAP_MANAGEMENT": false,
					"GAME_STATE": false,
					"ANIMATION": false,
					"LEVEL_MANAGEMENT": false,
					"AUTHENTICATION": false,
					"ROOM_MANAGEMENT": false,
					"RANKED_SYSTEM": false,
					"PLAYER_MANAGEMENT": false,
					"AUDIO": false
				}
			}
		
		DebugPreset.DEVELOPMENT:
			return {
				"level": Level.DEBUG,
				"categories": {
					"GENERAL": true,
					"PLAYER_INPUT": true,
					"MENU": true,
					"NETWORK": false,
					"MAP_GENERATION": true,
					"MAP_MANAGEMENT": true,
					"GAME_STATE": true,
					"ANIMATION": false,
					"LEVEL_MANAGEMENT": true,
					"AUTHENTICATION": false,
					"ROOM_MANAGEMENT": false,
					"RANKED_SYSTEM": true,
					"PLAYER_MANAGEMENT": true,
					"AUDIO": true
				}
			}
		
		DebugPreset.FULL_DEBUG:
			return {
				"level": Level.VERBOSE,
				"categories": {
					"GENERAL": true,
					"PLAYER_INPUT": true,
					"MENU": true,
					"NETWORK": true,
					"MAP_GENERATION": true,
					"MAP_MANAGEMENT": true,
					"GAME_STATE": true,
					"ANIMATION": true,
					"LEVEL_MANAGEMENT": true,
					"AUTHENTICATION": true,
					"ROOM_MANAGEMENT": true,
					"RANKED_SYSTEM": true,
					"PLAYER_MANAGEMENT": true,
					"AUDIO": true
				}
			}
		
		DebugPreset.HEADLESS_SERVER:
			return {
				"level": Level.DEBUG,
				"categories": {
					"GENERAL": true,
					"PLAYER_INPUT": false,
					"MENU": false,
					"NETWORK": true,
					"MAP_GENERATION": true,
					"MAP_MANAGEMENT": true,
					"GAME_STATE": true,
					"ANIMATION": false,
					"LEVEL_MANAGEMENT": true,
					"AUTHENTICATION": true,
					"ROOM_MANAGEMENT": true,
					"RANKED_SYSTEM": true,
					"PLAYER_MANAGEMENT": true,
					"AUDIO": false
				}
			}
		
		DebugPreset.CUSTOM:
			return {
				"level": CUSTOM_DEBUG_LEVEL,
				"categories": CUSTOM_CATEGORIES
			}
		
		_:
			return get_preset_settings(DebugPreset.DEVELOPMENT)

#endregion
