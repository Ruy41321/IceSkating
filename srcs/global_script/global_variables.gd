extends Node

#region IP

const SERVER_IP = "ec2-3-69-237-213.eu-central-1.compute.amazonaws.com"

#endregion

#region SCENE PATHS

var loading_screen_path: String = "res://scene/loadingScreen/LoadingScreen.tscn"
var tilemap_path: String = "res://scene/levels/tileMap/BaseTileMap.tscn"
var level_offline_path: String = "res://scene/levels/levelOffline/LevelOffline.tscn"
var level_online_path: String = "res://scene/levels/levelOnline/LevelOnline.tscn"
var start_menu_path: String = "res://scene/startMenu/StartMenu.tscn"
var player_online_path: String = "res://scene/player/playerOnline/PlayerOnline.tscn"
var player_offline_path: String = "res://scene/player/playerOffline/PlayerOffline.tscn"

#endregion

#region TILE MAPPING CONFIGURATION

# Character to atlas coordinates mapping
var tile_mapping = {
	"PTL": Vector2i(0, 0),
	"PTM": Vector2i(0, 1),
	"PTR": Vector2i(0, 2),
	"PL": Vector2i(1, 0),
	"PR": Vector2i(1, 2),
	"PBL": Vector2i(2, 0),
	"PBM": Vector2i(2, 1),
	"PBR": Vector2i(2, 2),
	"M": Vector2i(2, 3), # Wall
	"G": Vector2i(1, 1), # Ice
	"T": Vector2i(1, 3), # Terrain
	"I": Vector2i(2, 4), # Player spawn
	"E": Vector2i(1, 4), # Exit
	"B": Vector2i(0, 4), # Hole in ice
	"D": Vector2i(0, 3), # Damaged ice
	"1": Vector2i(1, 1), # Arrow right
	"2": Vector2i(1, 0), # Arrow left
	"3": Vector2i(0, 1), # Arrow down
	"4": Vector2i(0, 0), # Arrow up
}

# Character to tile ID mapping
var tile_id_mapping = {
	"PTL": 1,
	"PTM": 1,
	"PTR": 1,
	"PL": 1,
	"PR": 1,
	"PBL": 1,
	"PBM": 1,
	"PBR": 1,
	"M": 1, # Wall
	"G": 1, # Ice
	"T": 1, # Terrain
	"I": 1, # Player spawn
	"E": 1, # Exit
	"B": 1, # Hole in ice
	"D": 1, # Damaged ice
	"1": 0, # Arrow right
	"2": 0, # Arrow left
	"3": 0, # Arrow down
	"4": 0, # Arrow up
}

#endregion

#region STATE FLAGS

var map_gen_error: bool = false  # Flag for map generation errors
var is_option_panel_open: bool = false  # Flag to track if option panel is open
var last_option_panel_close_time: float = 0.0  # Timestamp when option panel was last closed

#endregion

#region ERROR FLAGS

#endregion

#region GAME STATE FLAGS

var exit_on_peer_disconnect: bool = false  # Flag to indicate if game exits on peer disconnect

#endregion

#region DEBUG HELPER FUNCTIONS

# Quick debug functions that can be used in any script
# These functions automatically reference the DebugManager autoload

func d_error(message: String, category: String = "GENERAL") -> void:
	"""Quick error debug function"""
	DebugManager.error(message, category)

func d_warning(message: String, category: String = "GENERAL") -> void:
	"""Quick warning debug function"""
	DebugManager.warning(message, category)

func d_info(message: String, category: String = "GENERAL") -> void:
	"""Quick info debug function"""
	DebugManager.info(message, category)

func d_debug(message: String, category: String = "GENERAL") -> void:
	"""Quick debug function"""
	DebugManager.debug(message, category)

func d_verbose(message: String, category: String = "GENERAL") -> void:
	"""Quick verbose debug function"""
	DebugManager.verbose(message, category)

# Category-specific helper functions for common debug scenarios
func d_player_input(message: String) -> void:
	"""Debug player input events"""
	d_debug(message, "PLAYER_INPUT")

func d_menu(message: String) -> void:
	"""Debug menu interactions"""
	d_debug(message, "MENU")

func d_network(message: String) -> void:
	"""Debug network events"""
	d_debug(message, "NETWORK")

func d_map_gen(message: String) -> void:
	"""Debug map generation"""
	d_debug(message, "MAP_GENERATION")

func d_game_state(message: String) -> void:
	"""Debug game state changes"""
	d_debug(message, "GAME_STATE")

func d_level_mgmt(message: String) -> void:
	"""Debug level management"""
	d_debug(message, "LEVEL_MANAGEMENT")

#endregion
