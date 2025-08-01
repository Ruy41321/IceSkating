class_name MapTerrain

static func is_valid_position(x: int, y: int, width: int, height: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

static func is_terrain_type(map: Array, x: int, y: int, terrain_types: Array) -> bool:
	return map[y][x] in terrain_types

static func is_wall(map: Array, x: int, y: int) -> bool:
	return map[y][x] == MapConstants.TERRAIN.WALL

static func is_ice(map: Array, x: int, y: int) -> bool:
	return map[y][x] == MapConstants.TERRAIN.ICE

static func is_stopping_terrain(map: Array, x: int, y: int) -> bool:
	return is_terrain_type(map, x, y, [MapConstants.TERRAIN.NORMAL, MapConstants.TERRAIN.START, MapConstants.TERRAIN.END])

static func is_conveyor_belt(map: Array, x: int, y: int) -> bool:
	return is_terrain_type(map, x, y, [MapConstants.TERRAIN.CONVEYOR_RIGHT, MapConstants.TERRAIN.CONVEYOR_LEFT, MapConstants.TERRAIN.CONVEYOR_DOWN, MapConstants.TERRAIN.CONVEYOR_UP])

static func get_conveyor_direction(map: Array, x: int, y: int) -> int:
	var conveyors = {
		MapConstants.TERRAIN.CONVEYOR_RIGHT: MapConstants.DIRECTIONS.RIGHT,
		MapConstants.TERRAIN.CONVEYOR_LEFT: MapConstants.DIRECTIONS.LEFT, 
		MapConstants.TERRAIN.CONVEYOR_DOWN: MapConstants.DIRECTIONS.DOWN,
		MapConstants.TERRAIN.CONVEYOR_UP: MapConstants.DIRECTIONS.UP
	}
	return conveyors.get(map[y][x], -1)

static func is_fragile_ice(map: Array, x: int, y: int) -> bool:
	return map[y][x] == MapConstants.TERRAIN.FRAGILE_ICE
		
static func is_deadly_terrain(map: Array, x: int, y: int) -> bool:
	return is_terrain_type(map, x, y, [MapConstants.TERRAIN.HOLE, MapConstants.TERRAIN.BROKEN_ICE])

static func break_ice_dict(map: Array, ice_broken_dict: Dictionary) -> Array:
	for pos in ice_broken_dict.keys():
		map[pos.y][pos.x] = MapConstants.TERRAIN.BROKEN_ICE
	return map

static func reset_broken_ice(map: Array, ice_broken_dict: Dictionary) -> Array:
	for pos in ice_broken_dict.keys():
		map[pos.y][pos.x] = MapConstants.TERRAIN.FRAGILE_ICE
	return map

static func create_simulate_move_result_dict(new_pos: Vector2i, map: Array, ice_broken: Dictionary) -> Array:
	map = reset_broken_ice(map, ice_broken)
	return [new_pos, ice_broken]

# Simula il movimento con scivolamento
static func simulate_move(map: Array, ice_broken_dict: Dictionary, x: int, y: int, dx: int, dy: int) -> Array:
	var width = map[0].size()
	var height = map.size()
		
	var new_pos = Vector2i(x + dx, y + dy)
		
	# Controlla validità posizione iniziale
	if not is_valid_position(new_pos.x, new_pos.y, width, height) or is_wall(map, new_pos.x, new_pos.y):
		return [Vector2i(x, y), ice_broken_dict]
		
	map = break_ice_dict(map, ice_broken_dict)
	
	if is_deadly_terrain(map, new_pos.x, new_pos.y):
		return create_simulate_move_result_dict(new_pos, map, ice_broken_dict)
		
	# Copia il dictionary (molto più veloce di array)
	var new_ice_broken = ice_broken_dict.duplicate()

	# Salva se era ghiaccio fragile PRIMA di trasformarlo
	var was_fragile_ice = is_fragile_ice(map, new_pos.x, new_pos.y)
		
	# Trasforma ghiaccio fragile in buco mortale al passaggio
	if was_fragile_ice:
		map[new_pos.y][new_pos.x] = MapConstants.TERRAIN.BROKEN_ICE
		new_ice_broken[new_pos] = true
		
	var current_direction = Vector2i(dx, dy)
		
	# Gestisce nastro trasportatore
	if is_conveyor_belt(map, new_pos.x, new_pos.y):
		var conv_dir = get_conveyor_direction(map, new_pos.x, new_pos.y)
		var new_dir = MapConstants.DIRECTION_VECTORS[conv_dir]
		var pushed_pos = Vector2i(new_pos.x + new_dir[0], new_pos.y + new_dir[1])
		
		if is_valid_position(pushed_pos.x, pushed_pos.y, width, height) and not is_wall(map, pushed_pos.x, pushed_pos.y):
			if is_deadly_terrain(map, pushed_pos.x, pushed_pos.y):
				return create_simulate_move_result_dict(pushed_pos, map, new_ice_broken)
			
			new_pos = pushed_pos
			current_direction = Vector2i(new_dir[0], new_dir[1])
			
			# Salva e trasforma ghiaccio fragile dopo spinta del nastro
			was_fragile_ice = is_fragile_ice(map, new_pos.x, new_pos.y)
			if was_fragile_ice:
				map[new_pos.y][new_pos.x] = MapConstants.TERRAIN.BROKEN_ICE
				new_ice_broken[new_pos] = true
	
		
	# Scivolamento su ghiaccio
	var iterations = 0
	var MAX_ITERATIONS = max(width, height)
		
	# USA la variabile salvata invece di controllare la mappa modificata
	while (is_ice(map, new_pos.x, new_pos.y) or was_fragile_ice) and iterations < MAX_ITERATIONS:
		iterations += 1
		var next_pos = Vector2i(new_pos.x + current_direction.x, new_pos.y + current_direction.y)
		
		if not is_valid_position(next_pos.x, next_pos.y, width, height) or is_wall(map, next_pos.x, next_pos.y):
			break
		
		new_pos = next_pos

		if is_deadly_terrain(map, new_pos.x, new_pos.y):
			break
		
		# Salva e trasforma ghiaccio fragile durante lo scivolamento
		was_fragile_ice = is_fragile_ice(map, new_pos.x, new_pos.y)
		if was_fragile_ice:
			map[new_pos.y][new_pos.x] = MapConstants.TERRAIN.BROKEN_ICE
			new_ice_broken[new_pos] = true

		
		if is_stopping_terrain(map, new_pos.x, new_pos.y):
			break
		
		# Gestione nastri durante scivolamento
		if is_conveyor_belt(map, new_pos.x, new_pos.y):
			var conv_dir = get_conveyor_direction(map, new_pos.x, new_pos.y)
			var new_dir = MapConstants.DIRECTION_VECTORS[conv_dir]
			var pushed_pos = Vector2i(new_pos.x + new_dir[0], new_pos.y + new_dir[1])
			
			if is_valid_position(pushed_pos.x, pushed_pos.y, width, height) and not is_wall(map, pushed_pos.x, pushed_pos.y):
				if is_deadly_terrain(map, pushed_pos.x, pushed_pos.y):
					new_pos = pushed_pos
					break
				
				new_pos = pushed_pos
				current_direction = Vector2i(new_dir[0], new_dir[1])
				
				# Trasforma ghiaccio fragile dopo spinta durante scivolamento
				was_fragile_ice = is_fragile_ice(map, new_pos.x, new_pos.y)
				if was_fragile_ice:
					map[new_pos.y][new_pos.x] = MapConstants.TERRAIN.BROKEN_ICE
					new_ice_broken[new_pos] = true
		
				
				if is_stopping_terrain(map, new_pos.x, new_pos.y):
					break
			else:
				break
		
	return create_simulate_move_result_dict(new_pos, map, new_ice_broken)
