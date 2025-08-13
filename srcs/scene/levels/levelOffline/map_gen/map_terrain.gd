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
	var start_pos = Vector2i(x, y)  # Salviamo la posizione iniziale
		
	var new_pos = Vector2i(x + dx, y + dy)
		
	# Controlla validità posizione iniziale
	if not is_valid_position(new_pos.x, new_pos.y, width, height) or is_wall(map, new_pos.x, new_pos.y):
		return [Vector2i(x, y), ice_broken_dict]
		
	map = break_ice_dict(map, ice_broken_dict)
	
	if is_deadly_terrain(map, new_pos.x, new_pos.y):
		return create_simulate_move_result_dict(new_pos, map, ice_broken_dict)
		
	# Copia il dictionary (molto più veloce di array)
	var new_ice_broken = ice_broken_dict.duplicate()

	# Salva se era ghiaccio fragile PRIMA di modificare la mappa
	var was_fragile_ice = is_fragile_ice(map, new_pos.x, new_pos.y)
	
	# IMPORTANTE: Non rompere subito il ghiaccio fragile, solo registrarlo per dopo
	# Il ghiaccio fragile si può attraversare, ma si rompe quando lo si LASCIA
	if was_fragile_ice:
		new_ice_broken[new_pos] = true
		# NON trasformiamo ancora il ghiaccio - lo faremo alla fine
		
	var current_direction = Vector2i(dx, dy)
	
	# Sistema di rilevamento loop: teniamo traccia dei conveyor belt visitati
	var visited_conveyors = {}
	
	# Sistema integrado: gestione movimento con conveyor belt e scivolamento
	var iterations = 0
	var MAX_ITERATIONS = max(width, height) * 2  # Aumentato per gestire conveyor belt complessi
	
	while iterations < MAX_ITERATIONS:
		iterations += 1
		
		# Prima gestiamo TUTTI i conveyor belt consecutivi dalla posizione attuale
		var conveyor_processed = false
		var conveyor_iterations = 0
		var MAX_CONVEYOR_ITERATIONS = 15  # Limite per conveyor belt consecutivi
		
		while is_conveyor_belt(map, new_pos.x, new_pos.y) and conveyor_iterations < MAX_CONVEYOR_ITERATIONS:
			conveyor_processed = true
			conveyor_iterations += 1
			
			# Crea una chiave unica per questo conveyor belt (posizione + direzione di input)
			var conveyor_key = str(new_pos.x) + "," + str(new_pos.y) + "," + str(current_direction.x) + "," + str(current_direction.y)
			
			# Se abbiamo già visitato questo conveyor belt con questa direzione, è un loop!
			if conveyor_key in visited_conveyors:
				# Loop rilevato! Restituisci la posizione di partenza per indicare "nessun progresso"
				return create_simulate_move_result_dict(start_pos, map, ice_broken_dict)
			
			# Registra questo conveyor belt come visitato
			visited_conveyors[conveyor_key] = true
			
			var conv_dir = get_conveyor_direction(map, new_pos.x, new_pos.y)
			var new_dir = MapConstants.DIRECTION_VECTORS[conv_dir]
			var pushed_pos = Vector2i(new_pos.x + new_dir[0], new_pos.y + new_dir[1])
			
			if not is_valid_position(pushed_pos.x, pushed_pos.y, width, height) or is_wall(map, pushed_pos.x, pushed_pos.y):
				break
				
			if is_deadly_terrain(map, pushed_pos.x, pushed_pos.y):
				new_pos = pushed_pos
				return create_simulate_move_result_dict(new_pos, map, new_ice_broken)
			
			new_pos = pushed_pos
			current_direction = Vector2i(new_dir[0], new_dir[1])
			
			# Gestisci ghiaccio fragile dopo ogni spinta del conveyor belt
			var was_fragile_ice_here = is_fragile_ice(map, new_pos.x, new_pos.y)
			if was_fragile_ice_here:
				map[new_pos.y][new_pos.x] = MapConstants.TERRAIN.BROKEN_ICE
				new_ice_broken[new_pos] = true
			
			# Se arriviamo su terreno che ferma, usciamo dal loop conveyor belt
			if is_stopping_terrain(map, new_pos.x, new_pos.y):
				break
		
		# Dopo aver processato tutti i conveyor belt, controlliamo se dobbiamo fermarci
		if is_stopping_terrain(map, new_pos.x, new_pos.y):
			break
			
		if is_deadly_terrain(map, new_pos.x, new_pos.y):
			break
		
		# Controlla se siamo su ghiaccio ADESSO (non basandoci su stato precedente)
		var current_is_fragile = is_fragile_ice(map, new_pos.x, new_pos.y)
		var current_is_ice = is_ice(map, new_pos.x, new_pos.y)
		var is_on_ice = current_is_ice or current_is_fragile
		
		# Se non siamo su ghiaccio e non abbiamo processato conveyor belt, fermiamoci
		if not is_on_ice and not conveyor_processed:
			break
		
		# Se siamo su ghiaccio, continuiamo a scivolare nella direzione attuale
		if is_on_ice:
			var next_pos = Vector2i(new_pos.x + current_direction.x, new_pos.y + current_direction.y)
			
			if not is_valid_position(next_pos.x, next_pos.y, width, height) or is_wall(map, next_pos.x, next_pos.y):
				break
			
			new_pos = next_pos
			
			# Registra ghiaccio fragile durante scivolamento (non rompere ancora)
			var fragile_at_next = is_fragile_ice(map, new_pos.x, new_pos.y)
			if fragile_at_next:
				new_ice_broken[new_pos] = true
		
		# Continua il loop per controllare di nuovo conveyor belt e scivolamento dalla nuova posizione
	
	# ALLA FINE: rompi tutti i ghiacci fragili che abbiamo attraversato
	for pos in new_ice_broken:
		if is_fragile_ice(map, pos.x, pos.y):
			map[pos.y][pos.x] = MapConstants.TERRAIN.BROKEN_ICE
	
	return create_simulate_move_result_dict(new_pos, map, new_ice_broken)
