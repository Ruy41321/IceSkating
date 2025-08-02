class_name PlayerOnline
extends PlayerBase

#region ONLINE SPECIFIC VARIABLES

# Player identity
var my_id: int
var is_local_player: bool = false  # True if this player is controlled by the local client

var has_fallen: bool = false  # Track if player has fallen into a hole
var grid_position_for_collision: Vector2

var direction_when_going_on_player: Vector2 = Vector2(-1, -1)

# Synchronization
var is_server_synced: bool = true

#endregion

#region ONLINE SPECIFIC OVERRIDES

func setup_player() -> void:
	"""Setup online player specific properties"""
	has_fallen = false

func setup_camera() -> void:
	"""Configure camera based on player type"""
	if is_local_player:
		cam.activate()
		LevelManager.set_end_game_panel(cam.option_panel)
	else:
		cam.deactivate()
	cam.set_player_id(my_id)

func should_process_input() -> bool:
	"""Check if this player should process input events"""
	if my_id != ClientManager.my_peer_id:
		return false
	if action_state == ActionState.MOVE or not is_server_synced or not can_move:
		return false
	
	# Don't process movement input when option panel is open
	if GlobalVariables.is_option_panel_open:
		return false
		
	return true

func start_movement() -> void:
	"""Initialize movement state"""
	super.start_movement()
	grid_position_for_collision = Vector2(-2, -2)
	is_server_synced = false

func on_movement_started(direction_vector: Vector2) -> void:
	"""Send movement to server"""
	send_movement_to_server(direction_vector)

func send_movement_to_server(direction_vector: Vector2) -> void:
	"""Send movement command to server"""
	ServerManager.get_client_input.rpc_id(1, ClientManager.current_room_id, direction_vector)

func is_position_occupied_by_other_player(pos: Vector2) -> bool:
	"""Check if position is occupied by another player"""
	var other_player = LevelManager.get_other_player(my_id)
	return other_player and pos == other_player.grid_position_for_collision

func on_player_collision(direction: Vector2) -> void:
	"""Handle collision with other player"""
	direction_when_going_on_player = direction

func handle_pre_movement_completion() -> bool:
	"""Handle player collision logic before movement completion"""
	if direction_when_going_on_player != Vector2(-1, -1):
		var next_pos = Vector2(final_grid_position.x, final_grid_position.y)
		next_pos.x += direction_when_going_on_player.x
		next_pos.y += direction_when_going_on_player.y
		if not is_position_occupied_by_other_player(next_pos):
			final_grid_position = calc_final_position(direction_when_going_on_player)
			direction_when_going_on_player = Vector2(-1, -1)  # Reset after using
			return true
		direction_when_going_on_player = Vector2(-1, -1)  # Reset after using
	return false

func on_grid_position_updated() -> void:
	"""Update grid position for collision detection"""
	grid_position_for_collision = final_grid_position

func handle_exit_tile() -> void:
	"""Handle reaching the exit tile"""
	can_move = false
	AudioManager.play_game_sfx("victory")

func handle_conveyor_belt(direction: MoveDirection, action_name: String) -> void:
	"""Handle conveyor belt tile effects"""
	current_animation_direction = direction
	if is_local_player:
		var event = InputEventAction.new()
		event.action = action_name
		event.pressed = true
		Input.parse_input_event(event)

func reset_player_state() -> void:
	"""Reset player state after falling"""
	super.reset_player_state()
	grid_position_for_collision = Vector2(-2, -2)

# fall_animation
func _on_animation_finished(animName: String, _has_win: bool) -> void:
	"""Handle animation finished events"""
	var other_player
	if animName == "fall":
		other_player = LevelManager.get_other_player(my_id)
		if other_player:
			cam.deactivate()
			if not other_player.has_fallen:
				other_player.cam.activate()
		else:
			# Single player mode - handle end game like offline mode
			if is_local_player:
				LevelManager.handle_end_game(false)

func complete_movement(target_position: Vector2) -> void:
	"""Complete movement and reset state"""
	position = target_position
	current_grid_position = final_grid_position
	on_grid_position_updated()
	action_state = ActionState.IDLE
	move_direction = MoveDirection.NONE
	
	# Reset movement speed for next movement
	current_move_speed = base_move_speed
	
	# Check if player stopped due to wall collision and play sound
	check_and_play_wall_collision_sound()

#endregion

#region NETWORK SYNCHRONIZATION

func sync_player_movement(player_id: int, direction: Vector2):
	"""Synchronize player movement from server"""
	if player_id != my_id:
		return
	
	update_animation_direction_from_vector(direction)
	final_grid_position = calc_final_position(direction)
	grid_position_for_collision = Vector2(-2, -2)
	action_state = ActionState.MOVE
	
	# Initialize acceleration for synced movement
	current_move_speed = base_move_speed
	movement_start_time = Time.get_ticks_msec() / 1000.0
	
	GlobalVariables.d_verbose(str(multiplayer.get_unique_id()) + " Player " + str(player_id) + " movement synced: " + str(direction) + " to " + str(final_grid_position), "PLAYER_INPUT")

func sync_player_position(player_id: int, server_grid_position: Vector2):
	"""Synchronize final player position from server"""
	if player_id != my_id:
		return
	update_position_from_server(server_grid_position)
	process_ice_breaking()
	handle_special_tiles()

func update_animation_direction_from_vector(direction: Vector2) -> void:
	"""Update animation direction based on movement vector"""
	if direction.y < 0:
		current_animation_direction = MoveDirection.UP
	elif direction.y > 0:
		current_animation_direction = MoveDirection.DOWN
	elif direction.x < 0:
		current_animation_direction = MoveDirection.LEFT
	elif direction.x > 0:
		current_animation_direction = MoveDirection.RIGHT

func update_position_from_server(server_grid_position: Vector2) -> void:
	"""Update player position based on server data"""
	current_grid_position = server_grid_position
	final_grid_position = server_grid_position
	grid_position_for_collision = server_grid_position
	position = tilemap.map_to_local(server_grid_position)
	is_server_synced = true
	move_direction = MoveDirection.NONE
	action_state = ActionState.IDLE

#endregion
