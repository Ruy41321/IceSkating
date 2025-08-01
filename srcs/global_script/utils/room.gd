class_name Room
extends Node

enum MatchState {
	NOT_STARTED,
	ONGOING,
	FINISHED
}

enum PlayerState {
	IDLE,
	MOVING,
	WAITING
}

var match_state: MatchState = MatchState.NOT_STARTED  # State of the match
var match_completion_strike: int = 0  # Number of match completed in a session

# Ranked mode variables
var is_ranked_mode: bool = false  # Indicates if this room is in ranked mode
var bonus_life_amount: int = 1  # Amount of bonus lives available for the current level
var starting_bonus_life_amount: int = 1  # Amount of bonus lives available at the start of the game

### Career mode variables

var maps_completed: int = -1  # Number of maps completed by the player in the room

###

var is_current_map_completed: bool = false  # Indicates if the current map has been completed (retrying a completed map will not increment the completion strike)

var room_id: String
var players_id: Array = []  # List of player IDs in the room (the id of the player in the database)
var peers_id: Array = []  # List of peer IDs in the room
var host_peer_id: int = -1  # The peer ID of the authoritative player (the host)
var map_name: String = ""
var map_id: int = -1  # The ID of the map in the database
var map_grid: Array = []  # Grid representation of the map

var map_grid_backup: Array = []  # Backup of the map grid to restore it after a match

var ice_to_break: Dictionary = {}  # List of ice tiles that can break (to be used in the multiplayer mode)

var player_spawned: Array = []  # List of player IDs that have spawned in the room

var players_pos: Dictionary = {}  # Dictionary to store player positions by their ID

var players_state: Dictionary = {}  # Dictionary to store player states by their ID

var direction_when_colliding_player: Dictionary = {}  # Dictionary to store  the direction when colliding with another player

func clear_game_data():
	# Clear the game data for a new match
	ice_to_break.clear()
	player_spawned.clear()
	players_pos.clear()
	players_state.clear()
	map_grid = map_grid_backup.duplicate()  # Restore the map grid from the backup

func reset_bonus_life_for_new_level():
	"""Reset bonus life availability for a new level in ranked mode"""
	if is_ranked_mode:
		bonus_life_amount = starting_bonus_life_amount
		GlobalVariables.d_debug("Bonus life reset for new ranked level", "RANKED_SYSTEM")

func use_bonus_life() -> bool:
	"""Use the bonus life if available. Returns true if used successfully"""
	if can_use_bonus_life():
		bonus_life_amount -= 1
		GlobalVariables.d_info("Bonus life used in ranked mode", "RANKED_SYSTEM")
		return true
	return false

func can_use_bonus_life() -> bool:
	"""Check if bonus life can be used"""
	return is_ranked_mode and bonus_life_amount > 0

func break_ice_tiles(player_id: int):
	# Break the ice tiles that can break
	if not ice_to_break.has(player_id):
		return  # No ice tiles to break for this player
	var player_pos = players_pos[player_id]
	for tile in ice_to_break[player_id]:
		if player_pos.x != tile.x || player_pos.y != tile.y:
			map_grid[tile.y][tile.x] = "B" 
	ice_to_break[player_id].clear()  # Clear the list after breaking the tiles

func someone_on_exit() -> bool:
	# Check if someone is on the exit tile
	for pos in players_pos.values():
		if map_grid[pos.y][pos.x] == "E":
			GlobalVariables.d_debug("Player on exit at position: " + str(pos), "GAME_STATE")
			return true
	return false

func everyone_on_hole() -> bool:
	# Check if everyone is on the hole tile
	for pos in players_pos.values():
		if map_grid[pos.y][pos.x] != "B" and (pos.y != -1 and pos.x != -1):
			return false
	return true

func player_on_hole(player_id: int) -> bool:
	# Check if the player is on the hole tile
	if not players_pos.has(player_id):
		return false  # Player not found
	var pos = players_pos[player_id]
	if map_grid[pos.y][pos.x] == "B":
		players_pos[player_id] = Vector2(-1, -1)  # Reset the position to an invalid state
		return true
	return false

func set_maps_completed() -> void:
	"""
	Set maps_completed variable to the highest value among all players in the room.
	Fetches data from the database via API call.
	"""
	if players_id.is_empty():
		GlobalVariables.d_warning("No players in room to get maps_completed data", "ROOM_MANAGEMENT")
		maps_completed = 0
		return
	
	# Filter out invalid player IDs (negative values used for testing)
	var valid_player_ids = []
	for player_id in players_id:
		if player_id > 0 and player_id not in valid_player_ids:  # Only include valid database IDs
			valid_player_ids.append(player_id)
	
	if valid_player_ids.is_empty():
		GlobalVariables.d_debug("No valid player IDs found, setting maps_completed to 0", "ROOM_MANAGEMENT")
		maps_completed = 0
		return
	
	GlobalVariables.d_debug("Getting max maps_completed for players: " + str(valid_player_ids), "ROOM_MANAGEMENT")
	
	# Call API to get max maps_completed value
	var result = await GameAPI.get_max_maps_completed(valid_player_ids)
	
	if result.success:
		maps_completed = result.max_maps_completed
		GlobalVariables.d_info("Room maps_completed set to: " + str(maps_completed), "ROOM_MANAGEMENT")
	else:
		GlobalVariables.d_error("Failed to get max maps_completed: " + str(result.error), "ROOM_MANAGEMENT")
		maps_completed = 0  # Fallback to 0 on error
