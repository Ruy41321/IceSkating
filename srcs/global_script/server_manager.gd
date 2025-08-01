extends Node

#region SERVER CONFIGURATION

var MAX_PLAYERS: int = 32
var SERVER_PORT = 7000
const SERVER_IP = "ec2-3-67-64-75.eu-central-1.compute.amazonaws.com"

#endregion

#region SERVER STATE

var current_room_id: String = ""
var authenticated_peers: Dictionary = {}
var rooms: Dictionary = {}  # Dictionary of Room objects, key = room_id
var waiting_peer: int = -1
var is_host: bool = false

#endregion

#region LEGACY VARIABLES

var player1_id = 0
var player2_id = 0
var level_node: Node = null

#endregion

#region INITIALIZATION

func _ready() -> void:
	var args = OS.get_cmdline_args()
	if "--server" in args:
		SERVER_PORT = int(args[1].replace("--port=", ""))
		MAX_PLAYERS = int(args[2].replace("--max-players=", ""))
		become_host()

func is_server() -> bool:
	"""Check if this instance is running as a server"""
	return is_host

#endregion

#region SERVER SETUP
func become_host() -> void:
	"""Initialize and start the dedicated server"""
	var peer = ENetMultiplayerPeer.new()

	if peer.create_server(SERVER_PORT, MAX_PLAYERS) != OK:
		push_error("Failed to start dedicated server")
		return
		
	multiplayer.multiplayer_peer = peer
	GlobalVariables.d_info("Relay server started: " + SERVER_IP + "::" + str(SERVER_PORT), "NETWORK")
	is_host = true
	
	setup_multiplayer_signals()

func setup_multiplayer_signals() -> void:
	"""Setup multiplayer connection signals"""
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	"""Handle new peer connection"""
	GlobalVariables.d_info("Peer connected: " + str(peer_id), "NETWORK")
	ClientManager.connection_established.rpc_id(peer_id)

#endregion

#region AUTHENTICATION

@rpc("any_peer")
func authenticate_peer(auth_token: String, username: String) -> void:
	"""Authenticate a peer using auth token and username"""
	var sender = multiplayer.get_remote_sender_id()
	
	# Force authentication for local testing
	if LevelManager.use_local_server:
		handle_local_authentication(sender, username)
		return
	
	# Check if peer is already authenticated
	if is_peer_already_authenticated(sender):
		return
	
	# Check if username is already in use
	if is_username_in_use(sender, username):
		return

	GlobalVariables.d_debug("Verifying token for peer: " + str(sender) + " user: " + username, "AUTHENTICATION")
	
	# Verify token with external API
	var verification_result = await GameAPI.verify_token(auth_token)
	
	# Handle verification result
	if is_verification_successful(verification_result):
		_handle_successful_verification(sender, username, verification_result.data.user)
	else:
		_handle_failed_verification(sender, verification_result.error)

func handle_local_authentication(sender: int, username: String) -> void:
	"""Handle authentication for local testing environment"""
	authenticated_peers[sender] = {
		"username": username,
		"user_id": -1,  # Placeholder for testing
		"best_score": 0,
		"maps_completed": 0
	}
	ClientManager.authentication_successfull.rpc_id(sender, authenticated_peers[sender])

func is_peer_already_authenticated(sender: int) -> bool:
	"""Check if peer is already authenticated"""
	if authenticated_peers.has(sender):
		GlobalVariables.d_warning("Peer: " + str(sender) + " already authenticated", "AUTHENTICATION")
		ClientManager.already_authenticated.rpc_id(sender)
		return true
	return false

func is_username_in_use(sender: int, username: String) -> bool:
	"""Check if username is already being used by another peer"""
	for peer in authenticated_peers:
		if username == authenticated_peers[peer].username:
			GlobalVariables.d_warning("Username already in use: " + username, "AUTHENTICATION")
			ClientManager.account_already_in_use.rpc_id(sender)
			return true
	return false

func is_verification_successful(verification_result: Dictionary) -> bool:
	"""Check if token verification was successful"""
	return verification_result.success and verification_result.data.has("valid") and verification_result.data.valid

#endregion

#region AUTHENTICATION HELPERS

func _handle_successful_verification(sender: int, username: String, user_data: Dictionary) -> void:
	"""Handle successful token verification"""
	# Verify username matches token data
	if user_data.username == username:
		_authenticate_user_successfully(sender, username, user_data)
	else:
		GlobalVariables.d_error("Username mismatch for peer " + str(sender) + " - token: " + user_data.username + " claimed: " + username, "AUTHENTICATION")
		ClientManager.authentication_failed.rpc_id(sender, "Username mismatch")

func _authenticate_user_successfully(sender: int, username: String, user_data: Dictionary) -> void:
	"""Complete user authentication successfully"""
	GlobalVariables.d_info("Peer: " + str(sender) + " authenticated as " + username, "AUTHENTICATION")
	authenticated_peers[sender] = {
		"username": username,
		"user_id": user_data.id,
		"best_score": user_data.bestScore,
		"maps_completed": user_data.mapsCompleted
	}
	ClientManager.authentication_successfull.rpc_id(sender, user_data)

func _handle_failed_verification(sender: int, error: String) -> void:
	"""Handle failed token verification"""
	GlobalVariables.d_error("Token verification failed for peer " + str(sender) + " - Error: " + error, "AUTHENTICATION")
	
	# Distinguish between network errors and invalid tokens
	if _is_network_error(error):
		_handle_network_error(sender)
	else:
		_handle_invalid_token(sender)

func _is_network_error(error: String) -> bool:
	"""Determine if error is network/timeout related"""
	return error.find("Timeout") != -1 or error.find("connect") != -1

func _handle_network_error(sender: int) -> void:
	"""Handle network/timeout errors from API server"""
	GlobalVariables.d_warning("API server offline, fallback authentication for peer " + str(sender), "AUTHENTICATION")
	ClientManager.authentication_failed.rpc_id(sender, "Authentication server temporarily unavailable")

func _handle_invalid_token(sender: int) -> void:
	"""Handle actually invalid tokens"""
	ClientManager.authentication_failed.rpc_id(sender, "Invalid token")

#endregion

#region ROOM MANAGEMENT

@rpc("any_peer")
func join_room(room_id: String) -> void:
	"""Handle peer request to join a room"""
	var sender = multiplayer.get_remote_sender_id()
	
	# Verify authentication
	if not authenticated_peers.has(sender):
		GlobalVariables.d_error("Peer " + str(sender) + " not authenticated", "AUTHENTICATION")
		ClientManager.authentication_failed.rpc_id(sender, "Not authenticated")
		return
	
	# Route to appropriate room handler
	match room_id:
		"ranked":
			await _handle_create_single_player_room(sender, true)
		"single_player":
			await _handle_create_single_player_room(sender)
		"new_private":
			_handle_create_private_room(sender)
		"quick_join":
			await _handle_quick_join(sender)
		_:
			# Try to join existing private room
			if rooms.has(room_id):
				await _handle_join_existing_private_room(room_id, sender)
			else:
				GlobalVariables.d_error("Private room not found: " + room_id, "ROOM_MANAGEMENT")
				ClientManager.room_not_found.rpc_id(sender, room_id)

#endregion

#region PEER DISCONNECTION

func _on_peer_disconnected(peer_id: int) -> void:
	"""Handle peer disconnection and cleanup"""
	GlobalVariables.d_info("Server: Peer disconnected: " + str(peer_id), "NETWORK")

	cleanup_peer_authentication(peer_id)
	cleanup_waiting_peer(peer_id)
	cleanup_peer_room(peer_id)

func cleanup_peer_authentication(peer_id: int) -> void:
	"""Remove peer from authenticated peers"""
	authenticated_peers.erase(peer_id)

func cleanup_waiting_peer(peer_id: int) -> void:
	"""Clear waiting peer if it matches the disconnected peer"""
	if waiting_peer == peer_id:
		waiting_peer = -1

func cleanup_peer_room(peer_id: int) -> void:
	"""Remove peer from room and handle room cleanup"""
	var room_to_remove = null
	var other_peer = -1

	# Find room containing the disconnected peer
	for room_id in rooms:
		var room = rooms[room_id]
		if peer_id in room.peers_id:
			# Find other peer in the room
			for other_peer_id in room.peers_id:
				if other_peer_id != peer_id:
					other_peer = other_peer_id
			room_to_remove = room_id
			break
	
	# Notify other peer if present (multiplayer only)
	if other_peer != -1:
		ClientManager.peer_disconnected.rpc_id(other_peer, peer_id)
	
	# Remove room (both single player and multiplayer)
	if room_to_remove != null:
		rooms.erase(room_to_remove)
		GlobalVariables.d_debug("Room removed after disconnection: " + room_to_remove, "ROOM_MANAGEMENT")

#endregion

#region UTILITY FUNCTIONS

func generate_room_id() -> String:
	"""Generate a unique room ID"""
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
	var id = ""
		
	while id == "" || rooms.has(id):
		id = ""
		for i in range(6):
			id += chars[randi() % chars.length()]
	return id

#endregion

#region ROOM CREATION HANDLERS

#endregion

#region ROOM MANAGEMENT

func _handle_create_single_player_room(sender: int, is_ranked: bool = false) -> void:
	"""Create and start single player room"""
	var room_id = generate_room_id()
	var new_room = create_new_room(room_id, sender, is_ranked)
	new_room.players_id.append(authenticated_peers[sender].get("user_id", -1))
	rooms[room_id] = new_room
	
	GlobalVariables.d_info("Single player room created: " + room_id + " for peer: " + str(sender), "ROOM_MANAGEMENT")
	await _load_map_and_start_single_player_game(new_room, room_id)
	
func _handle_create_private_room(sender: int) -> void:
	"""Create new private room"""
	var room_id = generate_room_id()
	var new_room = create_new_room(room_id, sender)
	new_room.players_id.append(authenticated_peers[sender].get("user_id", -1))
	rooms[room_id] = new_room
	
	GlobalVariables.d_info("Private room created: " + room_id, "ROOM_MANAGEMENT")
	ClientManager.room_created.rpc_id(sender, room_id)

func _handle_quick_join(sender: int) -> void:
	"""Handle quick join for public rooms"""
	if waiting_peer == -1:
		# First player waiting
		waiting_peer = sender
		GlobalVariables.d_debug("Peer " + str(sender) + " waiting for another player...", "ROOM_MANAGEMENT")
		ClientManager.waiting_for_opponent.rpc_id(sender)
	else:
		# Second player found - create room and start game
		await _create_public_room_and_start_game(waiting_peer, sender)
		waiting_peer = -1

func _create_public_room_and_start_game(player1: int, player2: int) -> String:
	"""Create public room and start game"""
	var room_id = generate_room_id()
	var new_room = create_new_room(room_id, player1)
	new_room.peers_id.append(player2)
	new_room.players_id.append(authenticated_peers[player1].get("user_id", -1))
	new_room.players_id.append(authenticated_peers[player2].get("user_id", -1))
	rooms[room_id] = new_room
	
	GlobalVariables.d_info("Room created: " + room_id + " with " + str(player1) + " and " + str(player2), "ROOM_MANAGEMENT")
	await _load_map_and_start_game(new_room, room_id)
	return room_id

func _handle_join_existing_private_room(room_id: String, sender: int) -> void:
	"""Handle joining existing private room"""
	var room = rooms[room_id]
		
	# Check if room is full
	if room.peers_id.size() >= 2:
		GlobalVariables.d_warning("Room full: " + room_id, "ROOM_MANAGEMENT")
		ClientManager.room_full.rpc_id(sender, room_id)
		return
	
	# Check if peer is already in room
	if sender in room.peers_id:
		GlobalVariables.d_warning("Already in private room: " + room_id, "ROOM_MANAGEMENT")
		ClientManager.already_in_room.rpc_id(sender, room_id)
		return
	
	# Add peer to room
	room.peers_id.append(sender)
	room.players_id.append(authenticated_peers[sender].get("user_id", -1))
	GlobalVariables.d_info("Peer " + str(sender) + " joined private room: " + room_id, "ROOM_MANAGEMENT")
	
	# Load map and start game
	await _load_map_and_start_game(room, room_id)

func create_new_room(room_id: String, host_peer_id: int, is_ranked: bool = false) -> Room:
	"""Create a new room instance with basic setup"""
	var new_room = Room.new()
	new_room.room_id = room_id
	new_room.host_peer_id = host_peer_id
	new_room.peers_id.append(host_peer_id)
	# Initialize ice_to_break for the host peer
	new_room.ice_to_break[host_peer_id] = []

	new_room.is_ranked_mode = is_ranked
	if new_room.is_ranked_mode:
		new_room.reset_bonus_life_for_new_level()
		GlobalVariables.d_info("Room created in ranked mode: " + room_id, "RANKED_SYSTEM")
	
	return new_room

#endregion

#region MAP LOADING AND GAME START

func _load_map_and_start_game(room: Room, room_id: String) -> void:
	"""Load map and start game for all peers in room"""
	
	# Set maps_completed from database for this room
	await room.set_maps_completed()
	
	var user1_id = str(authenticated_peers[room.peers_id[0]].get("user_id", -1))
	var user2_id = str(authenticated_peers[room.peers_id[1]].get("user_id", -1))
	
	var result = await MapManager.get_file_path(
		user1_id,
		user2_id,
		await LevelManager.get_online_difficulty(room)
	)
	
	if not process_map_loading_result(room, room_id, result):
		return
		
	start_game_for_all_peers(room, room_id)

func _load_map_and_start_single_player_game(room: Room, room_id: String) -> void:
	"""Load map and start single player game"""
	var user_id = str(authenticated_peers[room.peers_id[0]].get("user_id", -1))
	
	var result = await MapManager.get_file_path(
		user_id, 
		user_id, 
		await LevelManager.get_online_difficulty(room)
	)
	
	if not process_map_loading_result(room, room_id, result):
		return
		
	start_single_player_game(room, room_id)

func process_map_loading_result(room: Room, room_id: String, result: Dictionary) -> bool:
	"""Process map loading result and setup room data"""
	var map_file_path = result.get("file_path", "")
	var map_data = MapManager.get_map_data(map_file_path)
	
	if map_data.is_empty():
		GlobalVariables.d_error("Error loading map for room: " + room_id, "MAP_GENERATION")
		notify_map_loading_failed(room)
		return false
	
	# Save map data to room
	room.map_name = result.get("name", "Unknown Map")
	room.map_id = result.get("id", -1)
	room.map_grid = map_data.get("grid", [])
	room.map_grid_backup = room.map_grid.duplicate()  # Backup for match reset
	return true

func notify_map_loading_failed(room: Room) -> void:
	"""Notify all peers in room that map loading failed"""
	for peer_id in room.peers_id:
		ClientManager.map_loading_failed.rpc_id(peer_id)

func start_game_for_all_peers(room: Room, room_id: String) -> void:
	"""Start game for all peers in multiplayer room"""
	for peer_id in room.peers_id:
		ClientManager.start_game.rpc_id(peer_id, room_id, room.peers_id, room.host_peer_id, room.map_grid)
		# Initialize ice_to_break for each peer
		if not room.ice_to_break.has(peer_id):
			room.ice_to_break[peer_id] = []
	
	room.match_state = Room.MatchState.ONGOING
	handle_fake_win_condition(room_id)

func start_single_player_game(room: Room, room_id: String) -> void:
	"""Start single player game"""
	var peer_id = room.peers_id[0]
	ClientManager.start_game.rpc_id(peer_id, room_id, room.peers_id, room.host_peer_id, room.map_grid)
	room.match_state = Room.MatchState.ONGOING
	GlobalVariables.d_info("Single player game started for room: " + room_id, "ROOM_MANAGEMENT")
	handle_fake_win_condition(room_id)

func handle_fake_win_condition(room_id: String) -> void:
	"""Handle fake win condition for testing"""
	if LevelManager.use_fake_wins:
		await get_tree().create_timer(3.0).timeout
		handle_end_game(room_id, true)

#endregion

#region GAME STATE MANAGEMENT
func handle_end_game(room_id: String, has_win: bool) -> void:
	"""Handle game end event"""
	if not rooms.has(room_id):
		GlobalVariables.d_error("Room not found for end game: " + room_id, "ROOM_MANAGEMENT")
		return

	var room = rooms[room_id]
	room.match_state = Room.MatchState.FINISHED
	
	var win_strike = room.match_completion_strike

	if has_win:
		process_win_condition(room)
		win_strike += 1
	else:
		if not room.can_use_bonus_life():
			win_strike = 0
	# Notify all peers of game end
	for peer_id in room.peers_id:
		ClientManager.handle_end_game.rpc_id(peer_id, has_win, win_strike)

func process_win_condition(room: Room) -> void:
	"""Process win condition and update completion data"""
	# Only increment strike and reset bonus life in ranked mode when map wasn't already completed
	if not room.is_current_map_completed and room.is_ranked_mode:
		room.match_completion_strike += 1
		# Reset bonus life for next level in ranked mode
		room.reset_bonus_life_for_new_level()
	
	# Always mark map as completed and increment maps_completed when winning
	room.is_current_map_completed = true
	room.maps_completed += 1
	
	# For single player, use same player ID for both parameters
	var player_1_id = room.players_id[0]
	var player_2_id = room.players_id[1] if room.players_id.size() > 1 else player_1_id
	
	# Always call API to update database - use appropriate endpoint for each mode
	if room.is_ranked_mode:
		GameAPI.handle_ranked_game_completion(
			room.map_name,
			room.map_id,
			player_1_id,
			player_2_id,
			true,
			room.match_completion_strike
		)
	else:
		# For normal mode, call regular completion endpoint (match_completion_strike defaults to 0)
		GameAPI.handle_game_completion(
			room.map_name,
			room.map_id,
			player_1_id,
			player_2_id,
			true
		)

func process_loss_condition(room: Room) -> void:
	"""Process loss condition with bonus life logic for ranked mode"""
	if room.can_use_bonus_life():
		# Use bonus life in ranked mode
		room.use_bonus_life()
		GlobalVariables.d_info("Bonus life used, match_completion_strike preserved: " + str(room.match_completion_strike), "RANKED_SYSTEM")
		# Don't reset strike, player gets another chance
	else:
		# Reset strike if no bonus life available or not ranked mode
		room.match_completion_strike = 0
		GlobalVariables.d_debug("Match completion strike reset to 0", "GAME_STATE")

@rpc("any_peer")
func retry_level(room_id: String) -> void:
	"""Handle level retry request"""
	var room: Room = rooms.get(room_id)
	if not validate_room_host_request(room, room_id):
		return
	if room.is_ranked_mode:
		process_loss_condition(room)  # Reset strike if retry when not completed
	room.clear_game_data()  # Clear game data for new match
	for peer_id in room.peers_id:
		ClientManager.restart_match.rpc_id(peer_id)
	room.match_state = Room.MatchState.ONGOING
	handle_fake_win_condition(room_id)

@rpc("any_peer")
func continue_next_level(room_id: String) -> void:
	"""Handle continue to next level request"""
	var room = rooms.get(room_id)

	if not validate_room_continue_request(room, room_id):
		return
		
	# Distinguish between single player and multiplayer
	room.is_current_map_completed = false  # Reset for new level
	
	# Reset bonus life for new level in ranked mode
	if room.is_ranked_mode:
		room.reset_bonus_life_for_new_level()
	
	room.clear_game_data()  # Clear game data for new match
	
	if room.peers_id.size() == 1:
		await _load_map_and_start_single_player_game(room, room_id)
	else:
		await _load_map_and_start_game(room, room_id)

func validate_room_host_request(room: Room, room_id: String) -> bool:
	"""Validate that room exists and sender is host"""
	if room == null or room.host_peer_id != multiplayer.get_remote_sender_id():
		GlobalVariables.d_warning("Room not found or insufficient permissions: " + room_id, "ROOM_MANAGEMENT")
		return false
	return true

func validate_room_continue_request(room: Room, room_id: String) -> bool:
	"""Validate that room exists, is finished, and sender is host"""
	if room == null or room.match_state != Room.MatchState.FINISHED or room.host_peer_id != multiplayer.get_remote_sender_id():
		GlobalVariables.d_warning("Room not found or insufficient permissions: " + room_id, "ROOM_MANAGEMENT")
		return false
	return true

#endregion

#region PLAYER SPAWNING

@rpc("any_peer")
func notify_player_spawn(room_id: String, spawn_position: Vector2i) -> void:
	"""Handle player spawn notification"""
	var sender = multiplayer.get_remote_sender_id()
	
	if not validate_spawn_request(sender, room_id):
		return
	
	var room = rooms[room_id]
	process_player_spawn(room, sender, spawn_position)

func validate_spawn_request(sender: int, room_id: String) -> bool:
	"""Validate player spawn request"""
	if sender not in authenticated_peers:
		GlobalVariables.d_error("Unauthenticated peer: " + str(sender), "AUTHENTICATION")
		return false
		
	if not rooms.has(room_id):
		GlobalVariables.d_error("Room not found for spawn: " + room_id, "ROOM_MANAGEMENT")
		return false
		
	var room = rooms[room_id]
	if sender not in room.peers_id:
		GlobalVariables.d_error("Peer not authorized to spawn in room: " + room_id, "ROOM_MANAGEMENT")
		return false
		
	if sender in room.player_spawned:
		GlobalVariables.d_warning("Player already spawned in room: " + room_id, "ROOM_MANAGEMENT")
		return false
	
	return true

func process_player_spawn(room: Room, sender: int, spawn_position: Vector2i) -> void:
	"""Process player spawn and update room state"""
	room.player_spawned.append(sender)
	
	# Notify other player in multiplayer
	if room.peers_id.size() == 2:
		var peer_to_notify = room.peers_id[0] if room.peers_id[0] != sender else room.peers_id[1]
		ClientManager.receive_player_spawn.rpc_id(peer_to_notify, sender, spawn_position)
	
	# Update player position and state
	room.players_pos[sender] = spawn_position
	room.players_state[sender] = room.PlayerState.IDLE

#endregion

#region PLAYER MOVEMENT

@rpc("any_peer")
func get_client_input(room_id: String, direction: Vector2) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if sender not in authenticated_peers:
		GlobalVariables.d_error("Peer non autenticato: " + str(sender), "AUTHENTICATION")
		return
	
	if not rooms.has(room_id):
		GlobalVariables.d_error("Stanza non trovata per input: " + room_id, "ROOM_MANAGEMENT")
		return
	
	var room = rooms[room_id]
	if sender not in room.peers_id:
		GlobalVariables.d_error("Peer non autorizzato a inviare input nella stanza: " + room_id, "ROOM_MANAGEMENT")
		return
	
	if room.players_state.get(sender, room.PlayerState.IDLE) != room.PlayerState.IDLE:
		GlobalVariables.d_warning("Peer " + str(sender) + " is not idle, cannot move", "PLAYER_INPUT")
		return

	handle_movement(room, sender, direction, room.players_pos.get(sender, Vector2.ZERO))
	
func handle_movement(room: Room, sender: int, direction: Vector2, start_position: Vector2, is_first_movement: bool = true) -> void:
	var final_grid_position = move_player(room, sender, direction, start_position)
	var estimated_time = calc_estimated_time_to_pos(start_position, final_grid_position)
	if estimated_time > 0:
		if is_first_movement and room.peers_id.size() == 2:
			var peer_to_notify = room.peers_id[0] if room.peers_id[0] != sender else room.peers_id[1]
			LevelManager.move_other_players.rpc_id(peer_to_notify, sender, direction)
		room.players_state[sender] = room.PlayerState.MOVING
		#rimuoveere la position
		room.players_pos[sender] = Vector2(-2, -2)
		get_tree().create_timer(estimated_time).timeout.connect(handle_player_arrive.bind(room, sender, final_grid_position, direction))
	else:
		room.peers_id.any(
		func(peer_id):
			#GlobalVariables.d_debug("sending fix to " + str(peer_id) + " about " + str(sender), "PLAYER_INPUT")
			LevelManager.fix_player_position.rpc_id(peer_id, sender, final_grid_position)
		)

func is_colliding_player(room: Room, direction: Vector2, current_pos: Vector2) -> bool:
	"""Check if moving in the given direction collides with another player"""
	var next_pos = current_pos
	next_pos.x += direction.x
	next_pos.y += direction.y

	for pos in room.players_pos.values():
		if pos.x == next_pos.x and pos.y == next_pos.y:
			return true
	return false

func handle_player_arrive(room: Room, sender: int, final_grid_position: Vector2, direction: Vector2) -> void:
	var room_id = room.room_id
	room.players_state[sender] = room.PlayerState.IDLE  # Reset stato dopo il movimento
	#inserire controllo se posizione finale è occupata adesso usare la posizione precedente
	for pos in room.players_pos.values():
		if pos.x == final_grid_position.x and pos.y == final_grid_position.y:
			final_grid_position.x += (direction.x * -1)
			final_grid_position.y += (direction.y * -1)

	# Notifica tutti i peer della nuova posizione
	room.break_ice_tiles(sender)  # Rompe il ghiaccio se necessario
	if room.direction_when_colliding_player.has(sender):
		var new_direction = room.direction_when_colliding_player[sender]
		room.direction_when_colliding_player.erase(sender)  # Rimuove la direzione dopo il movimento
		if not is_colliding_player(room, new_direction, final_grid_position):
			handle_movement(room, sender, new_direction, final_grid_position, false)
			return
	room.players_pos[sender] = final_grid_position  # Aggiorna la posizione del giocatore
	room.peers_id.any(
		func(peer_id):
			#GlobalVariables.d_debug("sending fix to " + str(peer_id) + " about " + str(sender), "PLAYER_INPUT")
			LevelManager.fix_player_position.rpc_id(peer_id, sender, final_grid_position)
	)
	if room.someone_on_exit():
		handle_end_game(room_id, true)
	if room.player_on_hole(sender):
		room.players_state[sender] = room.PlayerState.WAITING
	if room.everyone_on_hole():
		handle_end_game(room_id, false)
	GlobalVariables.d_verbose(str(multiplayer.get_unique_id()) + " Peer: " + str(sender) + " moved to " + str(final_grid_position) + " in room " + room_id, "PLAYER_INPUT")

func calc_estimated_time_to_pos(starting_pos: Vector2, final_grid_position: Vector2) -> float:
	"""Calculate movement time considering acceleration physics"""
	var distance = starting_pos.distance_to(final_grid_position) * 32  # Convert grid distance to pixels
	
	# Movement acceleration parameters (same as PlayerBase)
	var base_move_speed: float = 150.0  # Starting speed in pixels per second
	var max_move_speed: float = 400.0   # Maximum speed in pixels per second
	var acceleration_rate: float = 300.0  # Acceleration in pixels per second squared
	
	# If distance is very small, use base speed
	if distance <= 1.0:
		return distance / base_move_speed
	
	# Calculate time using kinematic equations for accelerated movement
	# For distance with acceleration: d = v0*t + 0.5*a*t^2
	# Rearranged: 0.5*a*t^2 + v0*t - d = 0
	# Using quadratic formula: t = (-v0 + sqrt(v0^2 + 2*a*d)) / a
	
	var time_to_max_speed = (max_move_speed - base_move_speed) / acceleration_rate
	var distance_to_max_speed = base_move_speed * time_to_max_speed + 0.5 * acceleration_rate * time_to_max_speed * time_to_max_speed
	
	if distance <= distance_to_max_speed:
		# Movement completes before reaching max speed - use acceleration formula
		var discriminant = base_move_speed * base_move_speed + 2 * acceleration_rate * distance
		if discriminant >= 0:
			return (-base_move_speed + sqrt(discriminant)) / acceleration_rate
		else:
			# Fallback to base speed if calculation fails
			return distance / base_move_speed
	else:
		# Movement reaches max speed - acceleration phase + constant speed phase
		var remaining_distance = distance - distance_to_max_speed
		var constant_speed_time = remaining_distance / max_move_speed
		return time_to_max_speed + constant_speed_time

func move_player(room: Room, peer_id: int, direction: Vector2, current_pos: Vector2) -> Vector2:
	# Continua a muoverti nella direzione finché non incontri una condizione di stop
	var map_width = room.map_grid[0].length()
	var map_height = room.map_grid.size()
	
	var starting_pos = current_pos
	# Continua a muoverti nella direzione finché non incontri una condizione di stop
	while true:
		var next_pos = Vector2.ZERO
		next_pos.y = int(current_pos.y + direction.y)
		next_pos.x = int(current_pos.x + direction.x)
		
		# Verifica che la prossima posizione sia dentro i limiti della mappa
		if next_pos.x < 0 or next_pos.x >= map_width or next_pos.y < 0 or next_pos.y >= map_height:
			# Fuori dai limiti, fermati alla posizione attuale
			break
		
		for pos in room.players_pos.values():
			if pos.x == next_pos.x and pos.y == next_pos.y:
				# Un altro giocatore è già su questa posizione, fermati
				room.direction_when_colliding_player[peer_id] = direction
				return current_pos

		var next_tile = room.map_grid[next_pos.y][next_pos.x]

		match next_tile:
			"M":  # Muro - fermati prima (non entrare nella cella)
				break
			"G":  # Ghiaccio - slitta alla successiva
				current_pos = next_pos
				continue
			"T":  # Terra - fermati su essa
				current_pos = next_pos
				break
			"D":  # Ghiaccio dannaggiato - slitta alla successiva
				current_pos = next_pos
				if not room.ice_to_break.has(peer_id):
					room.ice_to_break[peer_id] = []
				room.ice_to_break[peer_id].append(next_pos)  # Aggiungi alla lista dei ghiacci da rompere
				continue
			"I":  # Ingresso - fermati su esso
				current_pos = next_pos
				break
			"E":  # Exit - fermati su essa
				current_pos = next_pos
				break
			"B":  # Tile speciale - fermati su essa
				current_pos = next_pos
				break
			"1", "2", "3", "4":  # Numeri - fermati su essi
				current_pos = next_pos
				break
			_:  # Tile sconosciuta - fermati prima per sicurezza
				break
	if room.map_grid[starting_pos.y][starting_pos.x] == "D":
		if not room.ice_to_break.has(peer_id):
			room.ice_to_break[peer_id] = []
		room.ice_to_break[peer_id].append(starting_pos)
	if room.map_grid[current_pos.y][current_pos.x] == "D":
		if room.ice_to_break.has(peer_id):
			room.ice_to_break[peer_id].erase(current_pos)  # Remove damaged ice if stopping on it
	return current_pos
