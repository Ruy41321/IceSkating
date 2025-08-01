extends Node

#region CONSTANTS

const SERVER_PORT = 7000
const SERVER_IP = "ec2-3-65-2-97.eu-central-1.compute.amazonaws.com"

#endregion

#region CONNECTION VARIABLES

var current_room_id: String = ""
var connection_status_label: Label
var start_menu_instance = null
var current_status_key: String = ""  # Memorizza la chiave di localizzazione attuale
var current_status_params: Array = []  # Memorizza i parametri per la stringa

#endregion

#region MULTIPLAYER STATE

var is_host: bool = false
var my_peer_id: int = 0
var other_peer_id: int = 0
var level_node: Node = null

#endregion

#region SCENE PATHS

var level_online_path: String = GlobalVariables.level_online_path
var start_menu_path: String = GlobalVariables.start_menu_path

#endregion

#region AUTHENTICATION DATA

var is_logged_in: bool = false
var user_data: Dictionary = {}

#endregion

#region CONNECTION MANAGEMENT

var connection_timeout_timer: Timer
var is_connecting: bool = false
var connection_success: bool = false

#endregion

#region CLIENT CONNECTION

func _ready() -> void:
	"""Initialize client manager and setup localization"""
	# Connetti al segnale di cambio lingua per aggiornare i messaggi
	LocalizationManager.language_changed.connect(_on_language_changed)

func _on_language_changed(_new_language: String) -> void:
	"""Update current status message when language changes"""
	if not current_status_key.is_empty() and connection_status_label and connection_status_label.visible:
		update_connection_status(current_status_key, current_status_params)

func become_client(room_id: String) -> void:
	"""Establish connection to server and join specified room"""
	if is_connecting:
		GlobalVariables.d_warning("Connection already in progress...", "NETWORK")
		return
		
	var client_peer = ENetMultiplayerPeer.new()
		
	var effective_server_ip = SERVER_IP if not LevelManager.use_local_server else "localhost"
	if client_peer.create_client(effective_server_ip, SERVER_PORT) != OK:
		push_error("Failed to create client connection")
		return
		
	multiplayer.multiplayer_peer = client_peer
	is_connecting = true
	connection_success = false
	current_room_id = room_id
	my_peer_id = multiplayer.get_unique_id()
	GlobalVariables.d_info("Attempting connection to server: " + effective_server_ip + "::" + str(SERVER_PORT), "NETWORK")
		
	setup_connection_timeout()

func setup_connection_timeout() -> void:
	"""Setup connection timeout timer to handle failed connections"""
	if connection_timeout_timer:
		connection_timeout_timer.queue_free()
		
	connection_timeout_timer = Timer.new()
	add_child(connection_timeout_timer)
	connection_timeout_timer.wait_time = 5.0  # 5 second timeout
	connection_timeout_timer.one_shot = true
	connection_timeout_timer.timeout.connect(_on_connection_timeout)
	connection_timeout_timer.start()

func _on_connection_timeout() -> void:
	"""Handle connection timeout"""
	if is_connecting and not connection_success:
		GlobalVariables.d_error("Connection timeout: Failed to connect to server", "NETWORK")
		is_connecting = false
		
		quit_connection()
		show_connection_error(LocalizationManager.get_text("connection_timeout"))
		start_menu_instance._on_multiplayer_button_pressed()

	cleanup_timeout_timer()

func cleanup_timeout_timer() -> void:
	"""Clean up the connection timeout timer"""
	if connection_timeout_timer:
		connection_timeout_timer.queue_free()
		connection_timeout_timer = null

func show_connection_error(error_message: String) -> void:
	"""Display connection error to user"""
	if connection_status_label:
		update_connection_status("connection_error", [error_message])

#endregion

#region CONNECTION CALLBACKS

@rpc("authority")
func connection_established() -> void:
	"""Called when connection to server is successfully established"""
	GlobalVariables.d_info("Connection established with server.", "NETWORK")
	is_connecting = false
	connection_success = true

	cleanup_timeout_timer()
	ServerManager.authenticate_peer.rpc_id(1, GameAPI.auth_token, user_data.get("username", ""))

#endregion

#region CONNECTION UTILITIES

func is_connection_open() -> bool:
	"""Check if connection to server is active"""
	return multiplayer.multiplayer_peer != null

func reset_variables() -> void:
	"""Reset all connection-related variables to default state"""
	current_room_id = ""
	is_host = false
	my_peer_id = 0
	other_peer_id = 0
	is_connecting = false
	connection_success = false
	current_status_key = ""
	current_status_params = []
	cleanup_timeout_timer()

func quit_connection() -> void:
	"""Close connection to server and reset state"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		reset_variables()
		GlobalVariables.d_info("Disconnected from server.", "NETWORK")

#endregion

#region PEER DISCONNECTION HANDLING

@rpc("authority")
func peer_disconnected(peer_id: int) -> void:
	"""Handle peer disconnection event"""
	GlobalVariables.d_info("Peer disconnected - ID: " + str(peer_id), "NETWORK")
	quit_connection()
	
	if get_tree().current_scene.name == "LevelOnline":
		GlobalVariables.exit_on_peer_disconnect = true
		get_tree().change_scene_to_file(start_menu_path)
	else:
		GlobalVariables.d_debug("Current scene: " + get_tree().current_scene.name, "GAME_STATE")

#endregion

#region ROOM STATUS MESSAGES

@rpc("authority")
func room_created(room_id: String) -> void:
	"""Display room creation confirmation"""
	update_connection_status("connection_room_created", [room_id])

@rpc("authority")
func waiting_for_opponent() -> void:
	"""Display waiting for opponent message"""
	update_connection_status("connection_waiting_opponent")

@rpc("authority")
func room_full(room_id: String) -> void:
	"""Display room full error"""
	update_connection_status("connection_room_full", [room_id])

@rpc("authority")
func already_in_room(room_id: String) -> void:
	"""Display already in room error"""
	update_connection_status("connection_already_in_room", [room_id])

@rpc("authority")
func room_not_found(room_id: String) -> void:
	"""Display room not found error"""
	update_connection_status("connection_room_not_found", [room_id])

func update_connection_status(localization_key: String, params: Array = []) -> void:
	"""Update connection status label with localized message"""
	if connection_status_label:
		current_status_key = localization_key
		current_status_params = params
		var message = LocalizationManager.get_text(localization_key)
		
		# Apply parameters if provided
		if params.size() > 0:
			message = message % params
		
		connection_status_label.visible = true
		connection_status_label.text = message

#endregion

#region GAME SESSION MANAGEMENT

@rpc("authority")
func start_game(room_id: String, peers_id: Array, host_peer_id: int, map_grid: Array) -> void:
	"""Initialize game session with provided data"""
	current_room_id = room_id
	determine_other_peer_id(peers_id)
	determine_host_status(host_peer_id)
	setup_game_environment(map_grid)

func determine_other_peer_id(peers_id: Array) -> void:
	"""Determine the other player's peer ID"""
	other_peer_id = peers_id[1] if peers_id[0] == my_peer_id and peers_id.size() >= 2 else peers_id[0]

func determine_host_status(host_peer_id: int) -> void:
	"""Determine if this client is the host"""
	is_host = (my_peer_id == host_peer_id)

func setup_game_environment(map_grid: Array) -> void:
	"""Setup game environment and transition to level"""
	MapManager.set_map_grid(map_grid)
	LevelManager.wipe_player_list()
	LevelManager.reset_bonus_life_for_new_level()
	get_tree().change_scene_to_file(level_online_path)

#endregion

#region AUTHENTICATION HANDLING

@rpc("authority")
func authentication_successfull(player_data: Dictionary) -> void:
	"""Handle successful authentication"""
	start_menu_instance.authentication_successfull(player_data)
	ServerManager.join_room.rpc_id(1, current_room_id)

@rpc("authority")
func authentication_failed(status: String) -> void:
	"""Handle failed authentication"""
	start_menu_instance.authentication_failed(status)
	quit_connection()

@rpc("authority")
func account_already_in_use() -> void:
	"""Handle account already in use error"""
	update_connection_status("connection_account_in_use")

#endregion

#region ERROR HANDLING

@rpc("authority")
func map_loading_failed() -> void:
	"""Handle map loading failure"""
	update_connection_status("connection_map_loading_failed")

@rpc("authority")
func handle_end_game(has_win: bool, win_strike: int = -1) -> void:
	"""Handle end game event"""
	if has_win and not LevelManager.is_ranked_mode:
		user_data.set("mapsCompleted", user_data.get("mapsCompleted", 0) + 1)
	LevelManager.handle_end_game(has_win, win_strike)

#endregion

#region LEVEL MANAGEMENT

func notify_retry() -> void:
	"""Request level retry (host only)"""
	if not is_host:
		GlobalVariables.d_warning("Only the host can manage the level.", "ROOM_MANAGEMENT")
		return
	ServerManager.retry_level.rpc_id(1, current_room_id)

@rpc("authority")
func restart_match() -> void:
	"""Restart current match"""
	LevelManager.wipe_player_list()
	MapManager.reset_map_grid()
	get_tree().reload_current_scene()

func notify_continue() -> void:
	"""Request continue to next level (host only)"""
	if not is_host:
		GlobalVariables.d_warning("Only the host can manage the level.", "ROOM_MANAGEMENT")
		return
	if LevelManager.is_ranked_mode:
		LevelManager.reset_bonus_life_for_new_level()
	LevelManager.wipe_player_list()
	ServerManager.continue_next_level.rpc_id(1, current_room_id)

func handle_exit() -> void:
	"""Handle game exit and cleanup"""
	if is_connection_open():
		quit_connection()
		
	if get_tree().current_scene.name == "LevelOnline":
		get_tree().change_scene_to_file(start_menu_path)
		LevelManager.wipe_player_list()
	else:
		GlobalVariables.d_debug("Current scene: " + get_tree().current_scene.name, "GAME_STATE")

#endregion

#region PLAYER SPAWNING

func notify_player_spawn(spawn_position: Vector2i) -> void:
	"""Notify server of player spawn position"""
	ServerManager.notify_player_spawn.rpc_id(1, current_room_id, spawn_position)

@rpc("authority")
func receive_player_spawn(sender_id: int, spawn_position: Vector2i) -> void:
	"""Handle received player spawn notification"""
	if sender_id == my_peer_id:
		return  # Don't handle own spawn
		
	if not get_tree().current_scene.has_method("spawn_player"):
		GlobalVariables.d_error("Current scene doesn't have 'spawn_player' method", "GAME_STATE")
		return
		
	get_tree().current_scene.spawn_player(spawn_position, sender_id)
	GlobalVariables.d_debug("Player spawn received from ID: " + str(sender_id) + " at position: " + str(spawn_position), "NETWORK")

#endregion

#region PLAYER_MANAGEMENT

func update_user_data() -> void:
	"""Update user_data dictionary with values from server"""
	if not GameAPI.is_authenticated():
		GlobalVariables.d_warning("Cannot update user data: user not authenticated", "PLAYER_MANAGEMENT")
		user_data.clear()
		is_logged_in = false
		return
	
	GlobalVariables.d_debug("Updating user data from server...", "PLAYER_MANAGEMENT")
	
	# Verify token and get updated user information
	var verification_result = await GameAPI.verify_token(GameAPI.auth_token)
	
	if verification_result.success and verification_result.data.has("valid") and verification_result.data.valid:
		# Extract user data from verification response
		var server_user_data = verification_result.data.get("user", {})

		var processed_user_data = GameAPI.convert_user_data_to_integers(server_user_data)
		# Update local user_data with server values
		user_data.clear()
		user_data = processed_user_data
		
		# Ensure is_logged_in reflects authentication status
		is_logged_in = true
		
		GlobalVariables.d_info("User data updated successfully", "PLAYER_MANAGEMENT")
	else:
		# Token verification failed - clear user data and logout
		GlobalVariables.d_error("Failed to update user data: token verification failed", "PLAYER_MANAGEMENT")
		user_data.clear()
		is_logged_in = false
		GameAPI.handle_token_expiration()

#endregion
