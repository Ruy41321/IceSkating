extends Node

var option_panel: OptionPanel

#region TESTING CONFIGURATIONS

var test_specific_difficulty: int = 0  # If > 0, uses this difficulty for testing purposes
var play_always_with_main_map: bool = false  # If true doesn switch map, useful for testing mechanics
var use_fake_wins: bool = false  # If true, uses fake wins for testing purposes
var use_local_server: bool = false  # If true, uses a local server for testing purposes without handling api's / database / authenitcation

#endregion

#region RANKED MODE CONFIGURATIONS

var is_ranked_mode: bool = false  # If true, uses ranked mode logic
var bonus_life_amount: int = 1  # Amount of bonus lives available in ranked mode
var starting_bonus_life_amount: int = 1  # Amount of bonus lives available at the start of the game

#endregion

#region LEVEL GEN OFFLINE CONFIGURATIONS

var new_map: bool = true  # If true, generates a new map instead of using the existing one (it has to be true the first map to dont use the previous map)

var difficulty_type: String = "hard"  # Default difficulty type

var main_map_name: String = "generated_map1"  # Name of the map to play
var reserve_map_name: String = "generated_map2"  # Name of the map to generate in advance

var current_map_name: String = ""

var has_retried: bool = false  # Flag to indicate if the player wanna retry the level

var tilemap: TileMapLayer
var player_spawn_position: Vector2i = Vector2i(-1, -1)  # Player spawn position in the grid

#endregion

#region GAME DATA

var current_moves_count = 0

#endregion

#region MULTIPLAYER PLAYER LIST

var player_list: Array = []  # List of players in the current game

#endregion

#region CORE METHODS

func set_end_game_panel(panel: OptionPanel):
	option_panel = panel

func is_playing_offline() -> bool:
	return get_tree().current_scene is LevelOffline

func handle_end_game(has_win: bool, win_strike: int = -1) -> void:
	if not option_panel:
		push_error("End game panel not found. Remember to set it in the level ready function.")	
		return
	option_panel.display_end_game(has_win, win_strike)

#endregion

#region OFFLINE MAP GEN UTILS

func get_offline_difficulty() -> String:
	if difficulty_type == "easy":
		return str(randi_range(1, 2))  # Random tra 1 e 2
	elif difficulty_type == "medium":
		return str(randi_range(3, 4))  # Random tra 3 e 4
	else:
		return "5"

func get_to_play_map_name() -> String:
	if has_retried or play_always_with_main_map:
		has_retried = false
		return current_map_name
	if current_map_name != main_map_name:
		current_map_name = main_map_name
		return current_map_name
	elif current_map_name != reserve_map_name:
		current_map_name = reserve_map_name
		return current_map_name
	else:
		push_error("Both map names are the same, cannot proceed.")
		return ""
	
func get_reserve_map_name() -> String:
	if current_map_name != main_map_name:
		return main_map_name
	elif current_map_name != reserve_map_name:
		return reserve_map_name
	else:
		push_error("Both map names are the same, cannot proceed.")
		return ""

#endregion

#region ONLINE MAP GEN UTILS

# Configurazione della scala di difficoltà per le partite online
# Modifica questi valori per cambiare la progressione della difficoltà
const DIFFICULTY_THRESHOLDS = {
	1: 0,   # Difficoltà 1 (facile): strike 0-1
	2: 2,   # Difficoltà 2: strike 2-4
	3: 5,   # Difficoltà 3 (medio): strike 5-9
	4: 10,  # Difficoltà 4: strike 10-19
	5: 20   # Difficoltà 5 (difficile): strike 20+
}

func get_online_difficulty(room: Room) -> String:
	"""
	Calcola la difficoltà basata sui livelli completati consecutivamente.
	
	Args:
		match_completion_strike: Numero di livelli completati di fila
		
	Returns:
		String: Difficoltà da "1" (facile) a "5" (difficile)
	"""
	if room.maps_completed < 0:
		await room.set_maps_completed()
	var maps_completed = room.maps_completed  # Numero di mappe completate
	
	if test_specific_difficulty > 0:
		return str(test_specific_difficulty)
	# In modalità ranked, usa sempre difficoltà 4-5
	if room.is_ranked_mode:
		return str(randi_range(4, 5))
	
	# Logica normale per modalità non-ranked

	# Trova la difficoltà appropriata
	var difficulty = 1
	
	for diff_level in [5, 4, 3, 2, 1]:  # Controlla dal più alto al più basso
		if maps_completed >= DIFFICULTY_THRESHOLDS[diff_level]:
			difficulty = diff_level
			break

	GlobalVariables.d_debug("Maps completed: " + str(maps_completed) + " -> Difficoltà: " + str(difficulty))
	return str(difficulty)

#endregion

#region MULTIPLAYER RPC METHODS
@rpc("authority")
func move_other_players(player_id: int, direction: Vector2) -> void:
	for player in player_list:
		if player.my_id == player_id:
			player.sync_player_movement(player_id, direction)
			return
	push_error("Player with ID %d not found in the player list." % player_id)

@rpc("authority")
func fix_player_position(player_id: int, server_grid_position: Vector2) -> void:
	for player in player_list:
		if player.my_id == player_id:
			player.sync_player_position(player_id, server_grid_position)
			return
	push_error("Player with ID %d not found in the player list." % player_id)

#endregion

#region PLAYER MANAGEMENT
func wipe_player_list() -> void:
	"""
	Wipes the player list, useful for resetting the game state.
	"""
	player_list.clear()
	GlobalVariables.d_debug("Player list wiped. Current size: " + str(player_list.size()), "PLAYER_MANAGEMENT")

func get_other_player(player_id: int) -> PlayerOnline:
	"""
	Retrieves a player from the player list by ID.
	
	Args:
		player_id: The ID of the player to retrieve
		
	Returns:
		PlayerOnline: The player object if found, None otherwise
	"""
	for player in player_list:
		if player.my_id != player_id:
			return player
	GlobalVariables.d_verbose("Player without ID %d not found." % player_id, "PLAYER_MANAGEMENT")
	return null

#endregion

#region UTILITIES

func reset_bonus_life_for_new_level() -> void:
	"""
	Resets the bonus life amount for the new level.
	"""
	bonus_life_amount = starting_bonus_life_amount  # Reset bonus life amount
