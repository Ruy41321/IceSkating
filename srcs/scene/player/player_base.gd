class_name PlayerBase
extends CharacterBody2D

#region NODE REFERENCES

@onready var cam: Camera2D = $PlayerCam
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

#endregion

#region ENUMS

enum ActionState { IDLE, MOVE }
enum MoveDirection { NONE, UP, DOWN, LEFT, RIGHT }

#endregion

#region CORE VARIABLES

var map_grid: Array = MapManager.get_map_grid()
var tilemap: TileMapLayer
var ice_to_break: Array = []  # List of ice tiles that can break

# Movement state
var action_state = ActionState.IDLE
var move_direction = MoveDirection.NONE
var final_grid_position: Vector2
var current_grid_position: Vector2

# Movement collision tracking
var hit_wall_during_movement: bool = false

# Player control
var can_move: bool = true

# Movement acceleration
var base_move_speed: float = 150.0  # Starting speed in pixels per second
var max_move_speed: float = 400.0   # Maximum speed in pixels per second
var acceleration_rate: float = 300.0  # Acceleration in pixels per second squared
var current_move_speed: float = 150.0  # Current movement speed
var movement_start_time: float = 0.0  # When current movement started

# Mobile touch controls
var touch_start_position: Vector2 = Vector2.ZERO
var is_touching: bool = false
var min_swipe_distance: float = 50.0  # Minimum distance for a valid swipe

#endregion

#region ANIMATION VARIABLES

var current_animation_direction: MoveDirection = MoveDirection.DOWN  # Default facing direction
var is_on_slippery_terrain: bool = false  # Track if player is on ice/slippery terrain
var animation_is_paused: bool = false  # Track if animation is manually paused

#endregion

#region CORE LIFECYCLE 

func _ready() -> void:
	setup_player()
	setup_camera()
	initialize_animation()

func _physics_process(delta: float) -> void:
	if not visible:
		return
	
	if action_state == ActionState.MOVE and can_move:
		handle_movement(delta)
	
	update_animation()

func _input(event: InputEvent) -> void:
	if not should_process_input() and not is_belt_push(event):
		return
	
	handle_directional_input(event)
	
	if is_movement_allowed():
		process_movement_request()

#endregion

#region VIRTUAL METHODS (TO BE OVERRIDDEN)

func setup_player() -> void:
	"""Override in derived classes for specific player setup"""
	pass

func setup_camera() -> void:
	"""Override in derived classes for camera configuration"""
	pass

func should_process_input() -> bool:
	"""Override in derived classes for input processing logic"""
	return action_state != ActionState.MOVE and can_move and not GlobalVariables.is_option_panel_open

func process_movement_request() -> void:
	"""Override in derived classes for movement request processing"""
	var direction_vector = get_direction_vector(move_direction)
	final_grid_position = calc_final_position(direction_vector)
	
	if final_grid_position != current_grid_position:
		start_movement()
		on_movement_started(direction_vector)
		return
	
	# Se il player non si muove, controlla se ha provato ad andare contro un muro
	check_wall_collision_when_stationary(direction_vector)
	move_direction = MoveDirection.NONE

func check_wall_collision_when_stationary(direction: Vector2) -> void:
	"""Check if player tried to move against a wall while stationary"""
	if direction == Vector2.ZERO:
		return
	
	var map_bounds = get_map_bounds()
	var target_pos = Vector2(
		current_grid_position.x + direction.x,
		current_grid_position.y + direction.y
	)
	
	# Se la posizione target è fuori bounds o è un muro, riproduci il suono
	if not is_position_in_bounds(target_pos, map_bounds):
		AudioManager.play_game_sfx("wall_collision")
		return
	
	var target_tile = map_grid[target_pos.y][target_pos.x]
	if target_tile == "M":
		AudioManager.play_game_sfx("wall_collision")

func on_movement_started(_direction_vector: Vector2) -> void:
	"""Override in derived classes for post-movement logic"""
	pass

func handle_exit_tile() -> void:
	"""Override in derived classes for exit tile handling"""
	can_move = false

func is_position_occupied_by_other_player(_pos: Vector2) -> bool:
	"""Override in derived classes for player collision detection"""
	return false

#endregion

#region INITIALIZATION

func initialize_animation() -> void:
	"""Initialize player animation state"""
	animation_player.play("RESET")
	update_animation()

#endregion

#region INPUT HANDLING

func handle_directional_input(event: InputEvent) -> void:
	"""Process directional input and update animation direction"""
	# Handle keyboard input
	if event.is_action_pressed("ui_up") or event.is_action_pressed("belt_up"):
		set_movement_direction(MoveDirection.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("belt_down"):
		set_movement_direction(MoveDirection.DOWN)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("belt_left"):
		set_movement_direction(MoveDirection.LEFT)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("belt_right"):
		set_movement_direction(MoveDirection.RIGHT)
	
	# Handle touch input for mobile
	elif event is InputEventScreenTouch:
		handle_touch_input(event)
	elif event is InputEventScreenDrag and is_touching:
		handle_drag_input(event)

func set_movement_direction(direction: MoveDirection) -> void:
	"""Set both movement and animation direction"""
	move_direction = direction
	current_animation_direction = direction

func start_movement() -> void:
	"""Initialize movement state"""
	action_state = ActionState.MOVE
	LevelManager.current_moves_count += 1
	
	# Initialize acceleration
	current_move_speed = base_move_speed
	movement_start_time = Time.get_ticks_msec() / 1000.0
	
	# Reset collision tracking
	hit_wall_during_movement = false

func is_movement_allowed() -> bool:
	"""Check if movement is currently allowed"""
	return MoveDirection.values().has(move_direction)

func handle_touch_input(event: InputEventScreenTouch) -> void:
	"""Handle touch screen input for mobile controls"""
	# Ignore touch input for a short time after menu was closed to prevent accidental movement
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_menu_close = current_time - GlobalVariables.last_option_panel_close_time
	var ignore_touch_delay = 0.3  # Ignore touch for 300ms after menu close
	
	if time_since_menu_close < ignore_touch_delay:
		return
	
	if event.pressed:
		# Start tracking touch
		touch_start_position = event.position
		is_touching = true
	else:
		# End touch - process swipe if valid
		if is_touching:
			process_swipe_gesture(event.position)
		is_touching = false

func handle_drag_input(event: InputEventScreenDrag) -> void:
	"""Handle screen drag input for immediate swipe detection"""
	if not is_touching:
		return
	
	var drag_distance = event.position.distance_to(touch_start_position)
	if drag_distance >= min_swipe_distance:
		# Process swipe immediately on sufficient drag distance
		process_swipe_gesture(event.position)
		is_touching = false  # Prevent multiple swipes

func process_swipe_gesture(end_position: Vector2) -> void:
	"""Process swipe gesture and determine movement direction"""
	var swipe_vector = end_position - touch_start_position
	var swipe_distance = swipe_vector.length()
	
	# Check if swipe is long enough
	if swipe_distance < min_swipe_distance:
		return
	
	# Determine primary direction based on largest component
	var abs_x = abs(swipe_vector.x)
	var abs_y = abs(swipe_vector.y)
	
	if abs_x > abs_y:
		# Horizontal swipe
		if swipe_vector.x > 0:
			set_movement_direction(MoveDirection.RIGHT)
		else:
			set_movement_direction(MoveDirection.LEFT)
	else:
		# Vertical swipe
		if swipe_vector.y > 0:
			set_movement_direction(MoveDirection.DOWN)
		else:
			set_movement_direction(MoveDirection.UP)

#endregion

#region MOVEMENT CALCULATIONS

func get_direction_vector(direction: MoveDirection) -> Vector2:
	"""Convert MoveDirection enum to Vector2"""
	match direction:
		MoveDirection.UP:
			return Vector2(0, -1)
		MoveDirection.DOWN:
			return Vector2(0, 1)
		MoveDirection.LEFT:
			return Vector2(-1, 0)
		MoveDirection.RIGHT:
			return Vector2(1, 0)
		_:
			return Vector2(0, 0)

func calc_final_position(direction: Vector2) -> Vector2:
	"""Calculate the final position considering map tiles and sliding mechanics"""
	if direction == Vector2.ZERO:
		return current_grid_position
	
	if not is_map_valid():
		return current_grid_position
	
	var map_bounds = get_map_bounds()
	var current_pos = current_grid_position
	var starting_pos = current_pos
	
	# Process movement through tiles
	current_pos = process_tile_movement(starting_pos, direction, map_bounds)
	
	# Handle special ice mechanics
	handle_ice_mechanics(starting_pos, current_pos)
	
	return current_pos

func is_map_valid() -> bool:
	"""Check if map data is loaded and valid"""
	if map_grid.is_empty():
		GlobalVariables.d_error("Map not loaded", "MAP_GENERATION")
		return false
	return true

func get_map_bounds() -> Dictionary:
	"""Get map width and height"""
	var map_height = map_grid.size()
	var map_width = map_grid[0].length() if map_height > 0 else 0
	return {"width": map_width, "height": map_height}

func process_tile_movement(start_pos: Vector2, direction: Vector2, map_bounds: Dictionary) -> Vector2:
	"""Process movement through different tile types"""
	var current_pos = start_pos
	
	while true:
		var next_pos = Vector2(
			current_pos.x + direction.x,
			current_pos.y + direction.y
		)
		
		if not is_position_in_bounds(next_pos, map_bounds):
			break
		
		if is_position_occupied_by_other_player(next_pos):
			on_player_collision(direction)
			break
		
		var tile_result = process_tile_interaction(current_pos, next_pos)
		if tile_result.should_stop:
			if tile_result.should_move_to_tile:
				current_pos = next_pos
			break
		
		current_pos = next_pos
	
	return current_pos

func on_player_collision(_direction: Vector2) -> void:
	"""Handle collision with other player - override in derived classes"""
	pass

func is_position_in_bounds(pos: Vector2, map_bounds: Dictionary) -> bool:
	"""Check if position is within map boundaries"""
	return pos.x >= 0 and pos.x < map_bounds.width and pos.y >= 0 and pos.y < map_bounds.height

func process_tile_interaction(_current_pos: Vector2, next_pos: Vector2) -> Dictionary:
	"""Process interaction with a specific tile type"""
	var next_tile = map_grid[next_pos.y][next_pos.x]
	
	match next_tile:
		"M":  # Wall - stop before entering (sound will be played when movement completes)
			return {"should_stop": true, "should_move_to_tile": false}
		"G":  # Ice - slide to next
			return {"should_stop": false, "should_move_to_tile": true}
		"T", "I", "E", "B", "1", "2", "3", "4":  # Stopping tiles
			return {"should_stop": true, "should_move_to_tile": true}
		"D":  # Damaged ice - slide and mark for breaking
			ice_to_break.append(next_pos)
			return {"should_stop": false, "should_move_to_tile": true}
		_:  # Unknown tile - stop for safety
			return {"should_stop": true, "should_move_to_tile": false}

func handle_ice_mechanics(starting_pos: Vector2, current_pos: Vector2) -> void:
	"""Handle special ice breaking mechanics"""
	if map_grid[starting_pos.y][starting_pos.x] == "D":
		ice_to_break.append(starting_pos)
	
	if map_grid[current_pos.y][current_pos.x] == "D":
		ice_to_break.erase(current_pos)

#endregion

#region MOVEMENT EXECUTION

func handle_movement(delta: float) -> void:
	"""Handle smooth movement between grid positions"""
	var target_position = tilemap.map_to_local(final_grid_position)
	var current_position = position
	
	var movement_data = calculate_movement_frame(current_position, target_position, delta)
	
	if movement_data.has_reached_target:
		if handle_pre_movement_completion():
			return
		complete_movement(target_position)
	else:
		continue_movement(movement_data.new_position)

func handle_pre_movement_completion() -> bool:
	"""Handle any logic before movement completion - override in derived classes"""
	return false

func calculate_movement_frame(current_pos: Vector2, target_pos: Vector2, delta: float) -> Dictionary:
	"""Calculate movement for current frame with acceleration"""
	var direction = (target_pos - current_pos).normalized()
	var distance_to_target = current_pos.distance_to(target_pos)
	
	# Calculate elapsed time since movement started
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed_time = current_time - movement_start_time
	
	# Apply acceleration: speed = initial_speed + acceleration * time
	current_move_speed = min(base_move_speed + acceleration_rate * elapsed_time, max_move_speed)
	
	var movement_this_frame = current_move_speed * delta
	
	GlobalVariables.d_verbose("Movement speed: %.1f px/s (elapsed: %.2fs)" % [current_move_speed, elapsed_time], "PLAYER_INPUT")
	return {
		"has_reached_target": distance_to_target <= movement_this_frame,
		"new_position": current_pos + direction * movement_this_frame,
		"direction": direction,
		"current_speed": current_move_speed
	}

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
	
	# Handle post-movement logic
	process_ice_breaking()
	handle_special_tiles()

func check_and_play_wall_collision_sound() -> void:
	"""Check if player stopped due to wall collision and play sound"""
	# Get the last movement direction
	var last_direction = get_direction_vector(current_animation_direction)
	if last_direction == Vector2.ZERO:
		return
	
	# Verifica se il player si è fermato a causa di un muro o per altri motivi
	var current_tile = map_grid[current_grid_position.y][current_grid_position.x]
	var map_bounds = get_map_bounds()
	var next_pos = Vector2(
		current_grid_position.x + last_direction.x,
		current_grid_position.y + last_direction.y
	)
	
	# Se il player è su una tile che ferma il movimento (T, I, E, B, 1-4), 
	# NON riprodurre il suono perché si è fermato per la tile corrente, non per un muro
	if current_tile in ["T", "I", "E", "B", "1", "2", "3", "4"]:
		# Il player si è fermato per la tile corrente, non per il muro
		# Non riprodurre alcun suono
		return
	
	# Se il player è su ghiaccio/ghiaccio danneggiato e c'è un muro nella direzione di movimento,
	# significa che si è fermato contro il muro durante la scivolata
	if current_tile in ["G", "D"]:
		if is_position_in_bounds(next_pos, map_bounds):
			var next_tile = map_grid[next_pos.y][next_pos.x]
			if next_tile == "M":
				AudioManager.play_game_sfx("wall_collision")

func on_grid_position_updated() -> void:
	"""Called when grid position is updated - override in derived classes"""
	pass

func continue_movement(new_position: Vector2) -> void:
	"""Continue movement towards target"""
	position = new_position
	current_grid_position = tilemap.local_to_map(position)

#endregion

#region GAME LOGIC

func process_ice_breaking() -> void:
	"""Process ice tiles that need to be broken"""
	for tile_pos in ice_to_break:
		map_grid[tile_pos.y][tile_pos.x] = "B"
		tilemap.set_cell(Vector2i(tile_pos.x, tile_pos.y), GlobalVariables.tile_id_mapping["B"], GlobalVariables.tile_mapping["B"])
		# Riproduce il suono di rottura del ghiaccio danneggiato
		AudioManager.play_game_sfx("ice_break")
	ice_to_break.clear()

func handle_special_tiles() -> void:
	"""Handle special tile effects after movement"""
	var current_tile = map_grid[current_grid_position.y][current_grid_position.x]
	
	match current_tile:
		"E":
			handle_exit_tile()
		"B":
			handle_on_hole()
		"1":
			handle_conveyor_belt(MoveDirection.RIGHT, "belt_right")
		"2":
			handle_conveyor_belt(MoveDirection.LEFT, "belt_left")
		"3":
			handle_conveyor_belt(MoveDirection.DOWN, "belt_down")
		"4":
			handle_conveyor_belt(MoveDirection.UP, "belt_up")

func is_belt_push(event: InputEvent) -> bool:
	"""Check if the event is a conveyor belt push action"""
	return event.is_action_pressed("belt_up") or event.is_action_pressed("belt_down") or \
		   event.is_action_pressed("belt_left") or event.is_action_pressed("belt_right")

func handle_conveyor_belt(direction: MoveDirection, action_name: String) -> void:
	"""Handle conveyor belt tile effects"""
	current_animation_direction = direction
	# Trigger automatic movement in the conveyor direction
	var event = InputEventAction.new()
	event.action = action_name
	event.pressed = true
	Input.parse_input_event(event)

#endregion

#region SPECIAL STATES

func handle_on_hole():
	"""Handle player falling into a hole"""
	AudioManager.play_game_sfx("player_fall")
	can_move = false
	play_fall_animation(false)
	reset_player_state()

func play_fall_animation(has_win: bool) -> void:
	"""Play fall animation and ensure it's not paused"""
	animation_player.play("fall")
	if animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.disconnect(_on_animation_finished)
	animation_player.animation_finished.connect(_on_animation_finished.bind(has_win))
	if animation_is_paused:
		animation_player.speed_scale = 1.0
		animation_is_paused = false

func reset_player_state() -> void:
	"""Reset player state after falling"""
	current_grid_position = Vector2(-1, -1)
	collision.disabled = true

# fall animation
func _on_animation_finished(_animation_name: String, _has_win: bool) -> void:
	"""Handle animation finished events - override in derived classes"""
	pass

#endregion

#region ANIMATION SYSTEM

func update_animation():
	"""Update player animation based on current state and terrain"""
	if animation_player.current_animation == "fall":
		return

	var terrain_type = get_current_terrain_type()
	update_terrain_state(terrain_type)
	
	if action_state == ActionState.IDLE:
		play_idle_animation()
	elif action_state == ActionState.MOVE:
		play_movement_animation()

func get_current_terrain_type() -> String:
	"""Get the terrain type at current position"""
	if not is_valid_grid_position():
		return "T"  # Default to normal terrain
	
	var map_bounds = get_map_bounds()
	if not is_position_in_bounds(current_grid_position, map_bounds):
		return "T"
	
	return map_grid[current_grid_position.y][current_grid_position.x]

func is_valid_grid_position() -> bool:
	"""Check if current grid position is valid"""
	return not map_grid.is_empty() and current_grid_position.y >= 0 and current_grid_position.x >= 0

func update_terrain_state(terrain_type: String):
	"""Update terrain state based on current tile type"""
	match terrain_type:
		"G", "D":  # Ice and damaged ice
			is_on_slippery_terrain = true
		_:  # All other terrain types
			is_on_slippery_terrain = false

func play_idle_animation():
	"""Play appropriate idle animation"""
	var animation_name = get_idle_animation_name(current_animation_direction)
	
	if should_change_animation(animation_name):
		animation_player.play(animation_name)
	
	ensure_animation_not_paused()

func play_movement_animation():
	"""Play appropriate movement animation based on terrain"""
	var animation_direction = get_effective_animation_direction()
	var animation_name = get_movement_animation_name(animation_direction)
	
	if should_change_animation(animation_name):
		animation_player.play(animation_name)
	
	if is_on_slippery_terrain:
		pause_animation_for_sliding()
	else:
		ensure_animation_not_paused()

func get_effective_animation_direction() -> MoveDirection:
	"""Get the effective direction for animation"""
	return move_direction if move_direction != MoveDirection.NONE else current_animation_direction

func should_change_animation(animation_name: String) -> bool:
	"""Check if animation should be changed"""
	return animation_player.current_animation != animation_name

func pause_animation_for_sliding() -> void:
	"""Pause animation to show sliding effect"""
	animation_player.speed_scale = 0.0
	animation_is_paused = true

func ensure_animation_not_paused() -> void:
	"""Ensure animation is playing normally"""
	if animation_is_paused:
		animation_player.speed_scale = 1.0
		animation_is_paused = false

#endregion

#region ANIMATION HELPERS

func get_idle_animation_name(direction: MoveDirection) -> String:
	"""Get idle animation name for direction"""
	match direction:
		MoveDirection.UP:
			return "idle_back"
		MoveDirection.DOWN:
			return "idle_front"
		MoveDirection.LEFT:
			return "idle_left"
		MoveDirection.RIGHT:
			return "idle_right"
		_:
			return "idle_front"  # Default

func get_movement_animation_name(direction: MoveDirection) -> String:
	"""Get movement animation name for direction"""
	match direction:
		MoveDirection.UP:
			return "walk_back"
		MoveDirection.DOWN:
			return "walk_front"
		MoveDirection.LEFT:
			return "walk_left"
		MoveDirection.RIGHT:
			return "walk_right"
		_:
			return "walk_front"  # Default

#endregion
