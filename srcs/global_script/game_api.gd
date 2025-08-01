# GameAPI.gd - API management class for server communication
extends Node

#region CONFIGURATION

const API_BASE_URL_CLIENT = "http://ec2-3-65-2-97.eu-central-1.compute.amazonaws.com:3000"
var REQUEST_TIMEOUT = 15  # HTTP request timeout in seconds

var auth_token: String = ""
var effective_api_base_url: String = ""
var api_status: String = "unknown"  # "online", "offline", "unknown"
var last_api_check: float = 0.0

var is_logging_in: bool = false

#endregion

#region HTTP REQUEST SETUP

var http_request: HTTPRequest

#endregion

#region SIGNALS

signal login_completed(success: bool, user_data: Dictionary, is_auto_login: bool)
signal login_failed(error_message: String)
signal leaderboard_loaded(leaderboard: Array)
signal map_completed(success: bool)

#endregion

#region INITIALIZATION

func _ready() -> void:
	"""Initialize the API manager and determine the correct API URL"""
	setup_http_request()
	configure_api_url()

func setup_http_request() -> void:
	"""Create and configure HTTP request node"""
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = REQUEST_TIMEOUT
	http_request.request_completed.connect(_on_request_completed)

func configure_api_url() -> void:
	"""Configure API URL based on command line arguments"""
	var args = OS.get_cmdline_args()
	if "--server" in args:
		effective_api_base_url = OS.get_environment("API_SERVER_URL")
	else:
		effective_api_base_url = API_BASE_URL_CLIENT	
		# Carica il token salvato all'avvio
		load_saved_auth_token()
	
	GlobalVariables.d_info("API URL configured: " + effective_api_base_url, "NETWORK")

func load_saved_auth_token() -> void:
	"""Carica il token di autenticazione e i dati utente salvati"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		auth_token = config.get_value("authentication", "token", "")
		if not auth_token.is_empty():
			GlobalVariables.d_info("Loaded saved auth token", "AUTHENTICATION")
			verify_saved_token()
		else:
			GlobalVariables.d_info("No saved auth token found", "AUTHENTICATION")
	else:
		GlobalVariables.d_info("No settings file found, starting fresh", "AUTHENTICATION")

func is_verification_successful(verification_result: Dictionary) -> bool:
	"""Check if token verification was successful"""
	return verification_result.success and verification_result.data.has("valid") and verification_result.data.valid

func verify_saved_token() -> void:
	"""Verifica se il token salvato è ancora valido"""
	if auth_token.is_empty():
		return
	
	var verification_result = await verify_token(auth_token)

	if is_verification_successful(verification_result):
		# Token valido, aggiorna i dati utente con quelli più recenti dal server
		var user_data = verification_result.data.user
		# Convert numeric values to integers before passing to UI
		var processed_user_data = convert_user_data_to_integers(user_data)
		
		GlobalVariables.d_info("Auto-login successful for user: " + str(processed_user_data.get("username", "Unknown")), "AUTHENTICATION")
		login_completed.emit(true, processed_user_data, true)  # true per is_auto_login
	else:
		# Token non valido, pulisci i dati salvati
		GlobalVariables.d_warning("Saved token is invalid, clearing authentication", "AUTHENTICATION")
		clear_saved_auth_token()
		clear_saved_user_data()
		auth_token = ""
		ClientManager.user_data = {}
		ClientManager.is_logged_in = false

func save_auth_token(token: String) -> void:
	"""Salva il token di autenticazione"""
	auth_token = token
	
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")  # Carica eventuali impostazioni esistenti
	
	# Se il caricamento fallisce, continua comunque con un ConfigFile vuoto
	if err != OK:
		GlobalVariables.d_info("Could not load existing config for token save, creating new one", "AUTHENTICATION")
	
	config.set_value("authentication", "token", token)
	var save_err = config.save("user://settings.cfg")
	
	if save_err == OK:
		GlobalVariables.d_info("Auth token saved", "AUTHENTICATION")
	else:
		GlobalVariables.d_error("Failed to save auth token: " + str(save_err), "AUTHENTICATION")

func clear_saved_auth_token() -> void:
	"""Rimuove il token di autenticazione salvato"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	# Se il caricamento fallisce, non c'è nulla da pulire
	if err != OK:
		GlobalVariables.d_info("No config file to clear token from", "AUTHENTICATION")
		return
	
	# Rimuovi solo il token, mantieni altre impostazioni
	config.set_value("authentication", "token", "")
	var save_err = config.save("user://settings.cfg")
	
	if save_err == OK:
		GlobalVariables.d_info("Auth token cleared", "AUTHENTICATION")
	else:
		GlobalVariables.d_error("Failed to clear auth token: " + str(save_err), "AUTHENTICATION")

func clear_saved_user_data() -> void:
	"""Rimuove i dati utente salvati"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	# Se il caricamento fallisce, non c'è nulla da pulire
	if err != OK:
		GlobalVariables.d_info("No config file to clear user data from", "AUTHENTICATION")
		return
	
	# Rimuovi la sezione user_data
	if config.has_section("user_data"):
		config.erase_section("user_data")
		var save_err = config.save("user://settings.cfg")
		if save_err == OK:
			GlobalVariables.d_info("User data cleared", "AUTHENTICATION")
		else:
			GlobalVariables.d_error("Failed to clear user data: " + str(save_err), "AUTHENTICATION")
	else:
		GlobalVariables.d_info("No user data section to clear", "AUTHENTICATION")

func handle_token_expiration() -> void:
	"""Gestisce la scadenza del token di autenticazione"""
	GlobalVariables.d_warning("Authentication token expired", "AUTHENTICATION")
	clear_saved_auth_token()
	clear_saved_user_data()
	auth_token = ""
	ClientManager.is_logged_in = false
	ClientManager.user_data = {}
	
	# Emetti un segnale per notificare che l'utente deve rifare il login
	login_failed.emit(LocalizationManager.get_error_message("INVALID_TOKEN"))

#endregion

#region API STATUS MANAGEMENT

func check_api_status() -> bool:
	"""
	Check API status with caching to avoid frequent requests.
	
	Returns:
		true if API is online, false otherwise
	"""
	if should_skip_status_check():
		return api_status == "online"
	
	update_last_check_timestamp()
	await perform_health_check()
	
	return api_status == "online"

func should_skip_status_check() -> bool:
	"""Check if we should skip status check based on last check time"""
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = get_timestamp_from_time(current_time)
	return current_timestamp - last_api_check < 30  # Check every 30 seconds

func get_timestamp_from_time(time_dict: Dictionary) -> float:
	"""Convert time dictionary to timestamp"""
	return time_dict.hour * 3600 + time_dict.minute * 60 + time_dict.second

func update_last_check_timestamp() -> void:
	"""Update the last API check timestamp"""
	var current_time = Time.get_time_dict_from_system()
	last_api_check = get_timestamp_from_time(current_time)

func perform_health_check() -> void:
	"""Perform health check on the API"""
	var test_result = await _make_sync_request(effective_api_base_url + "/health", [], HTTPClient.METHOD_GET)
	api_status = "online" if test_result.success else "offline"

#endregion

#region AUTHENTICATION

func register_user(username: String, password: String) -> void:
	"""
	Register a new user account.
	
	Args:
		username: Username for the new account
		password: Password for the new account
	"""
	var url = effective_api_base_url + "/api/auth/register"
	var headers = ["Content-Type: application/json"]
	var data = create_auth_data(username, password)
	
	var json_string = JSON.stringify(data)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	# Wait for response
	await http_request.request_completed

func login_user(username: String, password: String) -> void:
	"""
	Login with existing user credentials.
	
	Args:
		username: User's username
		password: User's password
	"""
	# Check if API is online first
	var is_online = await check_api_status()
	if not is_online:
		var localized_message = LocalizationManager.get_error_message("NETWORK_ERROR")
		login_failed.emit(localized_message)
		return
	
	var url = effective_api_base_url + "/api/auth/login"
	var headers = ["Content-Type: application/json"]
	var data = create_auth_data(username, password)
	
	var json_string = JSON.stringify(data)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)

func create_auth_data(username: String, password: String) -> Dictionary:
	"""Create authentication data dictionary"""
	return {
		"username": username,
		"password": password
	}

func verify_token(token: String) -> Dictionary:
	"""
	Verify if a token is valid.
	
	Args:
		token: Authentication token to verify
		
	Returns:
		Dictionary with verification result
	"""
	var url = effective_api_base_url + "/api/auth/verify"
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + token
	]
	
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_GET)
	return response

func is_authenticated() -> bool:
	"""Check if user is currently authenticated"""
	return not auth_token.is_empty() and ClientManager.is_logged_in

func logout() -> void:
	"""Logout the current user"""
	auth_token = ""
	clear_saved_auth_token()
	clear_saved_user_data()
	ClientManager.is_logged_in = false
	ClientManager.user_data = {}
	GlobalVariables.d_info("User logged out", "AUTHENTICATION")

#endregion

#region SCORE MANAGEMENT

func update_score(score: int) -> void:
	"""
	Update user's score.
	
	Args:
		score: New score value
	"""
	if not validate_authentication("update score"):
		return
	
	var url = effective_api_base_url + "/api/user/score"
	var headers = create_authenticated_headers()
	var data = {"score": score}
	
	var json_string = JSON.stringify(data)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)

func get_leaderboard(limit: int = 10, offset: int = 0) -> Dictionary:
	"""
	Get game leaderboard.
	
	Args:
		limit: Maximum number of results (default: 10, max: 100)
		offset: Number of results to skip for pagination (default: 0)
		
	Returns:
		Dictionary with leaderboard data
	"""
	var url = effective_api_base_url + "/api/leaderboard"
	var headers = ["Content-Type: application/json"]
	
	var query_params = "?limit=" + str(limit) + "&offset=" + str(offset)
	var full_url = url + query_params
	
	GlobalVariables.d_debug("Loading leaderboard - Limit: " + str(limit) + " Offset: " + str(offset), "NETWORK")
	
	var response = await _make_sync_request(full_url, headers, HTTPClient.METHOD_GET)
	
	if response.success and response.data.has("leaderboard"):
		var leaderboard_data = response.data.leaderboard
		# Convert numeric values to integers before returning
		var processed_leaderboard = convert_leaderboard_to_integers(leaderboard_data)
		GlobalVariables.d_info("Leaderboard loaded successfully: " + str(processed_leaderboard.size()) + " entries", "NETWORK")
		return create_success_response(processed_leaderboard, processed_leaderboard.size())
	else:
		GlobalVariables.d_error("Leaderboard loading error: " + response.error, "NETWORK")
		return create_error_response(response.error, [])

func create_success_response(leaderboard: Array, count: int) -> Dictionary:
	"""Create success response for leaderboard"""
	return {
		"success": true,
		"leaderboard": leaderboard,
		"count": count
	}

func create_error_response(error: String, default_leaderboard: Array) -> Dictionary:
	"""Create error response for leaderboard"""
	return {
		"success": false,
		"error": error,
		"leaderboard": default_leaderboard,
		"count": 0
	}

func get_levels_leaderboard(limit: int = 10, offset: int = 0) -> Dictionary:
	"""
	Get levels completed leaderboard.
	
	Args:
		limit: Maximum number of results (default: 10, max: 100)
		offset: Number of results to skip for pagination (default: 0)
		
	Returns:
		Dictionary with levels leaderboard data
	"""
	var url = effective_api_base_url + "/api/leaderboard/levels"
	var headers = ["Content-Type: application/json"]
	
	var query_params = "?limit=" + str(limit) + "&offset=" + str(offset)
	var full_url = url + query_params
	
	GlobalVariables.d_debug("Loading levels leaderboard - Limit: " + str(limit) + " Offset: " + str(offset), "NETWORK")
	
	var response = await _make_sync_request(full_url, headers, HTTPClient.METHOD_GET)
	
	if response.success and response.data.has("leaderboard"):
		var leaderboard_data = response.data.leaderboard
		# Convert numeric values to integers before returning
		var processed_leaderboard = convert_levels_leaderboard_to_integers(leaderboard_data)
		GlobalVariables.d_info("Levels leaderboard loaded successfully: " + str(processed_leaderboard.size()) + " entries", "NETWORK")
		return create_success_response(processed_leaderboard, processed_leaderboard.size())
	else:
		GlobalVariables.d_error("Levels leaderboard loading error: " + response.error, "NETWORK")
		return create_error_response(response.error, [])

#endregion

#region MAP MANAGEMENT

func get_maps() -> void:
	"""Get list of available maps"""
	var url = effective_api_base_url + "/api/maps"
	var headers = ["Content-Type: application/json"]
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func complete_map(map_id: int) -> void:
	"""
	Mark a map as completed.
	
	Args:
		map_id: ID of the completed map
	"""
	if not validate_authentication("complete map"):
		return
	
	var url = effective_api_base_url + "/api/user/complete-map"
	var headers = create_authenticated_headers()
	var data = {"mapId": map_id}
	
	var json_string = JSON.stringify(data)
	http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)

func get_uncompleted_map(difficulty: int, user_id1: int, user_id2: int) -> Array:
	"""
	Get the first uncompleted map for specified users.
	
	Args:
		difficulty: Map difficulty to search for
		user_id1: First user ID
		user_id2: Second user ID
		
	Returns:
		Array with [map_name, map_id] or empty array if not found
	"""
	if not validate_map_search_params(difficulty, user_id1, user_id2) or LevelManager.use_local_server:
		return []
	
	var url = build_uncompleted_map_url(difficulty, user_id1, user_id2)
	var headers = create_headers_with_optional_auth()
	
	GlobalVariables.d_debug("Searching uncompleted map - Difficulty: " + str(difficulty) + " Users: " + str(user_id1) + ", " + str(user_id2), "MAP_GENERATION")
	
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_GET)
	return process_uncompleted_map_response(response)

func validate_map_search_params(difficulty: int, user_id1: int, user_id2: int) -> bool:
	"""Validate parameters for map search"""
	if difficulty <= 0 or user_id1 <= 0 or user_id2 <= 0:
		push_error("Invalid parameters for get_uncompleted_maps")
		return false
	return true

func build_uncompleted_map_url(difficulty: int, user_id1: int, user_id2: int) -> String:
	"""Build URL for uncompleted map search"""
	var base_url = effective_api_base_url + "/api/maps/first-uncompleted"
	var query_params = "?difficulty=" + str(difficulty) + "&user_id1=" + str(user_id1) + "&user_id2=" + str(user_id2)
	return base_url + query_params

func create_headers_with_optional_auth() -> Array:
	"""Create headers with optional authentication"""
	var headers = ["Content-Type: application/json"]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer " + auth_token)
	return headers

func process_uncompleted_map_response(response: Dictionary) -> Array:
	"""Process response from uncompleted map search"""
	if response.success and response.data.has("mapName"):
		var map_name = response.data.mapName
		var map_id = response.data.mapId
		GlobalVariables.d_info("Map found: " + str(map_name) + " (ID: " + str(map_id) + ")", "MAP_MANAGEMENT")
		return [map_name, map_id]
	elif response.code == 404:
		GlobalVariables.d_debug("No uncompleted map found for specified parameters", "MAP_MANAGEMENT")
		return []
	else:
		GlobalVariables.d_error("Error searching map: " + str(response.error), "MAP_MANAGEMENT")
		return []

func create_map(map_name: String, difficulty: int) -> Dictionary:
	"""
	Create a new map in the database.
	
	Args:
		map_name: Map name (3-100 characters)
		difficulty: Map difficulty (1-10)
		
	Returns:
		Dictionary with operation result
	"""
	if LevelManager.use_local_server:
		return {"success": false, "error": "Local server mode does not support map creation"}
	var url = effective_api_base_url + "/api/maps/new"
	var headers = ["Content-Type: application/json"]
	
	var data = {
		"map_name": map_name,
		"difficulty": difficulty
	}
	
	var json_string = JSON.stringify(data)
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if response.success:
		GlobalVariables.d_info("Map created successfully: " + str(response.data.mapName), "MAP_MANAGEMENT")
		return create_map_success_response(response.data)
	else:
		GlobalVariables.d_error("Map creation error: " + str(response.error), "MAP_MANAGEMENT")
		return {"success": false, "error": response.error}

func create_map_success_response(data: Dictionary) -> Dictionary:
	"""Create success response for map creation"""
	return {
		"success": true,
		"map_id": data.mapId,
		"map_name": data.mapName,
		"difficulty": data.difficulty
	}

func update_map_stats(map_name: String, incr_played: bool, incr_completed: bool) -> Dictionary:
	"""
	Update map statistics (played_times and/or completed_times).
	
	Args:
		map_name: Name of the map to update
		incr_played: If true, increment played_times by 1
		incr_completed: If true, increment completed_times by 1
		
	Returns:
		Dictionary with operation result
	"""
	var url = effective_api_base_url + "/api/maps/update-stats"
	var headers = ["Content-Type: application/json"]
	
	var data = {
		"map_name": map_name,
		"incr_played": incr_played,
		"incr_completed": incr_completed
	}
	
	GlobalVariables.d_debug("Updating map statistics: " + str(map_name) + " (played: " + str(incr_played) + ", completed: " + str(incr_completed) + ")", "MAP_MANAGEMENT")
	
	var json_string = JSON.stringify(data)
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if response.success:
		GlobalVariables.d_info("Map statistics updated successfully", "MAP_MANAGEMENT")
		return create_map_stats_success_response(response.data)
	else:
		GlobalVariables.d_error("Map statistics update error: " + str(response.error), "MAP_MANAGEMENT")
		return {"success": false, "error": response.error}

func create_map_stats_success_response(data: Dictionary) -> Dictionary:
	"""Create success response for map statistics update"""
	return {
		"success": true,
		"data": data,
		"error": ""
	}

func create_completion_success_response(data: Dictionary) -> Dictionary:
	"""Create success response for map completion registration"""
	return {
		"success": true,
		"data": data,
		"error": ""
	}

func create_completion_error_response(error: String) -> Dictionary:
	"""Create error response for map completion registration"""
	return {
		"success": false,
		"data": {},
		"error": error
	}

func register_map_completion(user_id: int, map_id: int, match_completion_strike: int) -> Dictionary:
	"""
	Register map completion by a user.
	
	Args:
		user_id: ID of the user who completed the map
		map_id: ID of the completed map
		match_completion_strike: Completion strike value
		
	Returns:
		Dictionary with operation result
	"""
	var url = effective_api_base_url + "/api/maps/user-completed"
	var headers = ["Content-Type: application/json"]
	
	var data = {
		"user_id": user_id,
		"map_id": map_id,
		"completation_strike": match_completion_strike
	}
	
	GlobalVariables.d_debug("Registering completion: User " + str(user_id) + ", Map " + str(map_id), "MAP_MANAGEMENT")
	
	var json_string = JSON.stringify(data)
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if response.success:
		GlobalVariables.d_info("Completion registered successfully", "MAP_MANAGEMENT")
		return create_completion_success_response(response.data)
	else:
		GlobalVariables.d_error("Failed to register completion: " + str(response.error), "MAP_MANAGEMENT")
		return create_completion_error_response(response.error)

func register_ranked_map_completion(user_id: int, map_id: int, match_completion_strike: int) -> Dictionary:
	"""
	Register ranked map completion by a user (only updates best_score, doesn't increment map_completed).
	
	Args:
		user_id: ID of the user who completed the map
		map_id: ID of the completed map
		match_completion_strike: Completion strike value (used as score)
		
	Returns:
		Dictionary with operation result
	"""
	var url = effective_api_base_url + "/api/ranked/user-completed"
	var headers = ["Content-Type: application/json"]
	
	var data = {
		"user_id": user_id,
		"map_id": map_id,
		"completation_strike": match_completion_strike
	}
	
	GlobalVariables.d_debug("Registering ranked completion: User " + str(user_id) + ", Map " + str(map_id) + ", Score " + str(match_completion_strike), "RANKED_SYSTEM")
	
	var json_string = JSON.stringify(data)
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if response.success:
		GlobalVariables.d_info("Ranked completion registered successfully", "RANKED_SYSTEM")
		return create_completion_success_response(response.data)
	else:
		GlobalVariables.d_error("Failed to register ranked completion: " + str(response.error), "RANKED_SYSTEM")
		return create_completion_error_response(response.error)
	
func handle_game_completion(map_name: String, map_id: int, user_id1: int, user_id2: int, has_win: bool = false, match_completion_strike: int = 0) -> void:
	"""
	Handle game completion combining statistics update and completion registration.
	
	Args:
		map_name: Map name
		map_id: Map ID
		user_id1: First player ID
		user_id2: Second player ID
		has_win: Whether there was a winner
		match_completion_strike: Completion strike value
	"""
	if has_win:
		await update_map_statistics_on_completion(map_name, has_win)
		await register_completion_for_both_players(map_id, user_id1, user_id2, match_completion_strike)
	
	GlobalVariables.d_debug("Game completion handling finished for map: " + str(map_name), "GAME_STATE")

func handle_ranked_game_completion(map_name: String, map_id: int, user_id1: int, user_id2: int, has_win: bool = false, match_completion_strike: int = 0) -> void:
	"""
	Handle ranked game completion - only updates statistics and best score, not map completion count.
	
	Args:
		map_name: Map name
		map_id: Map ID
		user_id1: First player ID
		user_id2: Second player ID
		has_win: Whether there was a winner
		match_completion_strike: Completion strike value (used as score in ranked)
	"""
	if has_win:
		await update_map_statistics_on_completion(map_name, has_win)
		await register_ranked_completion_for_both_players(map_id, user_id1, user_id2, match_completion_strike)
	
	GlobalVariables.d_debug("Ranked game completion handling finished for map: " + str(map_name), "RANKED_SYSTEM")

func update_map_statistics_on_completion(map_name: String, has_win: bool) -> void:
	"""Update map statistics when game is completed"""
	var stats_result = await update_map_stats(map_name, false, has_win)
	if not stats_result.success:
		GlobalVariables.d_error("Error updating statistics for map: " + str(map_name), "MAP_MANAGEMENT")

func register_completion_for_both_players(map_id: int, user_id1: int, user_id2: int, match_completion_strike: int) -> void:
	"""Register completion for both players"""
	var completion_result = await register_map_completion(user_id1, map_id, match_completion_strike)
	if not completion_result.success:
		GlobalVariables.d_error("Error registering completion for winner: " + str(user_id1), "MAP_MANAGEMENT")
	
	if user_id1 != user_id2:
		completion_result = await register_map_completion(user_id2, map_id, match_completion_strike)
		if not completion_result.success:
			GlobalVariables.d_error("Error registering completion for winner: " + str(user_id2), "MAP_MANAGEMENT")

func register_ranked_completion_for_both_players(map_id: int, user_id1: int, user_id2: int, match_completion_strike: int) -> void:
	"""Register ranked completion for both players (only tracks completion, doesn't increment map_completed counter)"""
	var completion_result = await register_ranked_map_completion(user_id1, map_id, match_completion_strike)
	if not completion_result.success:
		GlobalVariables.d_error("Error registering ranked completion for winner: " + str(user_id1), "RANKED_SYSTEM")
	
	if user_id1 != user_id2:
		completion_result = await register_ranked_map_completion(user_id2, map_id, match_completion_strike)
		if not completion_result.success:
			GlobalVariables.d_error("Error registering ranked completion for winner: " + str(user_id2), "RANKED_SYSTEM")

func get_max_maps_completed(user_ids: Array) -> Dictionary:
	"""
	Get the maximum maps_completed value among specified users.
	
	Args:
		user_ids: Array of user IDs to check
		
	Returns:
		Dictionary with operation result containing max_maps_completed value
	"""
	if user_ids.is_empty():
		GlobalVariables.d_warning("Empty user_ids array provided to get_max_maps_completed", "MAP_MANAGEMENT")
		return {"success": false, "error": "No user IDs provided", "max_maps_completed": 0}
	
	var url = effective_api_base_url + "/api/users/max-maps-completed"
	var headers = ["Content-Type: application/json"]
	
	var data = {
		"user_ids": user_ids
	}
	
	GlobalVariables.d_debug("Getting max maps completed for users: " + str(user_ids), "MAP_MANAGEMENT")
	
	var json_string = JSON.stringify(data)
	var response = await _make_sync_request(url, headers, HTTPClient.METHOD_POST, json_string)
	
	if response.success:
		var max_value = response.data.get("max_maps_completed", 0)
		GlobalVariables.d_info("Max maps completed retrieved: " + str(max_value), "MAP_MANAGEMENT")
		return {
			"success": true,
			"max_maps_completed": int(max_value),
			"error": ""
		}
	else:
		GlobalVariables.d_error("Failed to get max maps completed: " + str(response.error), "MAP_MANAGEMENT")
		return {
			"success": false,
			"error": response.error,
			"max_maps_completed": 0
		}

#endregion

#region USER PROFILE

func get_user_profile() -> void:
	"""Get current user's profile information"""
	if not validate_authentication("get user profile"):
		return
	
	var url = effective_api_base_url + "/api/user/profile"
	var headers = create_authenticated_headers()
	
	http_request.request(url, headers, HTTPClient.METHOD_GET)

#endregion

#region USER DATA PROCESSING

func convert_user_data_to_integers(user_data: Dictionary) -> Dictionary:
	"""
	Convert numeric user data values to integers for consistent display.
	
	Args:
		user_data: Raw user data from server
		
	Returns:
		Dictionary with numeric values converted to integers
	"""
	var processed_data = user_data.duplicate()
	
	# Convert numeric fields that should be displayed as integers
	var numeric_fields = ["mapsCompleted", "bestScore", "rank"]
	
	for field in numeric_fields:
		if processed_data.has(field):
			var value = processed_data[field]
			# Convert to int if it's a number, keep original value otherwise
			if value is float or value is int:
				processed_data[field] = int(value)
	
	return processed_data

func convert_leaderboard_to_integers(leaderboard: Array) -> Array:
	"""
	Convert numeric leaderboard values to integers for consistent display.
	
	Args:
		leaderboard: Raw leaderboard data from server
		
	Returns:
		Array with numeric values converted to integers
	"""
	var processed_leaderboard = []
	
	# Convert numeric fields that should be displayed as integers
	var numeric_fields = ["best_score", "position"]
	
	for player in leaderboard:
		var processed_player = player.duplicate()
		
		for field in numeric_fields:
			if processed_player.has(field):
				var value = processed_player[field]
				# Convert to int if it's a number, keep original value otherwise
				if value is float or value is int:
					processed_player[field] = int(value)
		
		processed_leaderboard.append(processed_player)
	
	return processed_leaderboard

func convert_levels_leaderboard_to_integers(leaderboard: Array) -> Array:
	"""
	Convert numeric levels leaderboard values to integers for consistent display.
	
	Args:
		leaderboard: Raw levels leaderboard data from server
		
	Returns:
		Array with numeric values converted to integers
	"""
	var processed_leaderboard = []
	
	# Convert numeric fields that should be displayed as integers
	var numeric_fields = ["map_completed", "position"]
	
	for player in leaderboard:
		var processed_player = player.duplicate()
		
		for field in numeric_fields:
			if processed_player.has(field):
				var value = processed_player[field]
				# Convert to int if it's a number, keep original value otherwise
				if value is float or value is int:
					processed_player[field] = int(value)
		
		processed_leaderboard.append(processed_player)
	
	return processed_leaderboard

#endregion

#region UTILITY FUNCTIONS

func validate_authentication(action: String) -> bool:
	"""Validate that user is authenticated for a specific action"""
	if auth_token.is_empty():
		GlobalVariables.d_warning("Error: user not authenticated for action: " + str(action), "AUTHENTICATION")
		return false
	return true

func create_authenticated_headers() -> Array:
	"""Create headers with authentication token"""
	return [
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	]

#endregion

#region HTTP REQUEST HANDLING

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Handle HTTP request completion"""
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		GlobalVariables.d_error("JSON parsing error: " + body.get_string_from_utf8(), "NETWORK")
		var localized_message = LocalizationManager.get_error_message("SERVER_ERROR")
		login_failed.emit(localized_message)
		REQUEST_TIMEOUT *= 1.5
		return
	
	var response_data = json.data
	
	# Handle different responses based on response code
	match response_code:
		200, 201:
			_handle_success_response(response_data)
		400:
			handle_client_error(response_data, "Request error")
		401:
			handle_auth_error(response_data)
		403:
			handle_forbidden_error(response_data)
		404:
			handle_not_found_error(response_data)
		409:
			handle_conflict_error(response_data)
		500:
			handle_server_error(response_data)
		_:
			handle_unknown_error(response_code, response_data)

func handle_client_error(response_data: Dictionary, error_type: String) -> void:
	"""Handle 400 Bad Request errors"""
	var error_message = response_data.get("error", "Unknown error")
	GlobalVariables.d_error(error_type + ": " + str(error_message), "NETWORK")
	emit_localized_error(error_message)

func handle_auth_error(response_data: Dictionary) -> void:
	"""Handle 401 Unauthorized errors"""
	var error_message = response_data.get("error", "Invalid token")
	GlobalVariables.d_error("Authentication error: " + str(error_message), "AUTHENTICATION")
	
	# Se c'era un token salvato, significa che è scaduto
	if not auth_token.is_empty():
		handle_token_expiration()
	else:
		emit_localized_error(error_message)

func handle_forbidden_error(response_data: Dictionary) -> void:
	"""Handle 403 Forbidden errors"""
	var error_message = response_data.get("error", "Access denied")
	GlobalVariables.d_warning("Access denied: " + str(error_message), "AUTHENTICATION")
	emit_localized_error(error_message)

func handle_not_found_error(response_data: Dictionary) -> void:
	"""Handle 404 Not Found errors"""
	var error_message = response_data.get("error", "Not found")
	GlobalVariables.d_warning("Resource not found: " + str(error_message), "NETWORK")
	emit_localized_error(error_message)

func handle_conflict_error(response_data: Dictionary) -> void:
	"""Handle 409 Conflict errors"""
	var error_message = response_data.get("error", "Resource already exists")
	GlobalVariables.d_warning("Conflict: " + str(error_message), "NETWORK")
	emit_localized_error(error_message)

func handle_server_error(response_data: Dictionary) -> void:
	"""Handle 500 Internal Server Error"""
	var error_message = response_data.get("error", "Internal server error")
	GlobalVariables.d_error("Server error: " + str(error_message), "NETWORK")
	emit_localized_error(error_message)

func handle_unknown_error(response_code: int, response_data: Dictionary) -> void:
	"""Handle unknown error codes"""
	GlobalVariables.d_error("Unknown error: " + str(response_code) + " " + str(response_data), "NETWORK")

func _handle_success_response(data: Dictionary) -> void:
	"""Handle successful HTTP responses"""
	if data.has("token"):
		handle_login_response(data)
	elif data.has("leaderboard"):
		handle_leaderboard_response(data)
	elif data.has("maps"):
		handle_maps_response(data)
	elif data.has("message") and data.message.find("completata") != -1:
		handle_map_completion_response()
	else:
		GlobalVariables.d_debug("Response received: " + str(data), "NETWORK")

func handle_login_response(data: Dictionary) -> void:
	"""Handle login response"""
	if not is_logging_in:
		return
	
	var token = data.get("token", "")
	if not token.is_empty():
		# Salva il token per login automatico futuro
		save_auth_token(token)
	
	var user_data = data.get("user", {})
	# Convert numeric values to integers before passing to UI
	var processed_user_data = convert_user_data_to_integers(user_data)
	
	login_completed.emit(true, processed_user_data, false)  # false per login manuale
	GlobalVariables.d_info("Login successful for: " + str(processed_user_data.get("username", "")), "AUTHENTICATION")

func handle_leaderboard_response(data: Dictionary) -> void:
	"""Handle leaderboard response"""
	var leaderboard = data.leaderboard
	leaderboard_loaded.emit(leaderboard)
	GlobalVariables.d_info("Leaderboard loaded with " + str(leaderboard.size()) + " elements", "GAME_STATE")

func handle_maps_response(data: Dictionary) -> void:
	"""Handle maps list response"""
	var maps = data.maps
	GlobalVariables.d_debug("Received " + str(maps.size()) + " maps", "MAP_MANAGEMENT")

func handle_map_completion_response() -> void:
	"""Handle map completion response"""
	map_completed.emit(true)
	GlobalVariables.d_info("Map completed successfully", "GAME_STATE")

func _make_sync_request(url: String, headers: Array, method: int, data: String = "") -> Dictionary:
	"""
	Helper function for synchronous requests.
	
	Args:
		url: Request URL
		headers: Request headers
		method: HTTP method
		data: Request body data
		
	Returns:
		Dictionary with response data
	"""
	var http = HTTPRequest.new()
	add_child(http)
	
	# Configure timeout
	http.timeout = REQUEST_TIMEOUT
	
	var request_result = http.request(url, headers, method, data)
	if request_result != OK:
		http.queue_free()
		return create_request_error_response()
	
	# Wait for response using await
	var response = await http.request_completed
	var result = response[0]
	var response_code = response[1]
	var _response_headers = response[2]  # Unused but present for completeness
	var body = response[3]
	
	http.queue_free()
	
	# Process response
	return process_response(result, response_code, body)

func create_request_error_response() -> Dictionary:
	"""Create error response for failed HTTP request"""
	return {
		"success": false,
		"code": 0,
		"data": {},
		"error": "Error sending HTTP request"
	}

func process_response(result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	"""Process HTTP response and return formatted data"""
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	var response_data = {
		"success": response_code >= 200 and response_code < 300,
		"code": response_code,
		"data": json.data if parse_result == OK else {},
		"error": ""
	}
	
	# Handle specific errors
	if result != HTTPRequest.RESULT_SUCCESS:
		response_data.success = false
		response_data.error = get_network_error_message(result)
	elif not response_data.success:
		response_data.error = get_api_error_message(parse_result, json.data)
	
	return response_data

func get_network_error_message(result: int) -> String:
	"""Get error message for network errors"""
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Unable to connect to API server"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Unable to resolve server address"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error to server"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "SSL/TLS error"
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timeout"
		_:
			return "Unknown network error"

func get_api_error_message(parse_result: int, data: Dictionary) -> String:
	"""Get error message for API errors"""
	if parse_result == OK and data.has("error"):
		return data.error
	else:
		return "API server error"

#endregion

#region ERROR HANDLING

func map_server_error_to_code(error_message: String) -> String:
	"""
	Mappa i messaggi di errore del server a codici di errore standardizzati
	
	Args:
		error_message: Messaggio di errore dal server
		
	Returns:
		Codice di errore standardizzato
	"""
	var error_lower = error_message.to_lower()
	
	# Mappa i messaggi del server ai codici di errore
	if "credenziali non valide" in error_lower or "invalid credentials" in error_lower:
		return "INVALID_CREDENTIALS"
	elif "username già esistente" in error_lower or "username already exists" in error_lower:
		return "USERNAME_EXISTS"
	elif "token non valido" in error_lower or "invalid token" in error_lower:
		return "INVALID_TOKEN"
	elif "utente non trovato" in error_lower or "user not found" in error_lower:
		return "USER_NOT_FOUND"
	elif "server not available" in error_lower or "server non disponibile" in error_lower:
		return "NETWORK_ERROR"
	elif "errore interno" in error_lower or "server error" in error_lower or "internal error" in error_lower:
		return "SERVER_ERROR"
	elif "richiesta non valida" in error_lower or "invalid request" in error_lower or "bad request" in error_lower:
		return "INVALID_REQUEST"
	else:
		return "UNKNOWN"

func emit_localized_error(error_message: String) -> void:
	"""
	Emette un errore localizzato basato sul messaggio del server
	
	Args:
		error_message: Messaggio di errore dal server
	"""
	var error_code = map_server_error_to_code(error_message)
	var localized_message = LocalizationManager.get_error_message(error_code)
	login_failed.emit(localized_message)

#endregion
