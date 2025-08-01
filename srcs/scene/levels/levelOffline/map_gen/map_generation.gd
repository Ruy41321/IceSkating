class_name MapGeneration

static func create_empty_map(width: int, height: int) -> Array:
	var map = []
	for y in range(height):
		var row = []
		for x in range(width):
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				row.append('M')
			else:
				row.append('G')
		map.append(row)
	return map
static func place_start_and_end(map: Array, start_pos: Array, end_pos: Array):
	var width = map[0].size()
	var height = map.size()
		
	# Posiziona l'ingresso casualmente
	start_pos[0] = 1 + randi() % (width - 2)
	start_pos[1] = 1 + randi() % (height - 2)
	map[start_pos[1]][start_pos[0]] = 'I'
		
	# Trova una posizione per l'uscita sufficientemente lontana
	var max_attempts = 5
	var best_distance = 0
	var best_end_x = -1
	var best_end_y = -1
	#print("---------------")
	for attempt in range(max_attempts):
		var candidate_x = 1 + randi() % (width - 2)
		var candidate_y = 1 + randi() % (height - 2)
		
		# Calcola la distanza euclidea
		var distance = sqrt(pow(candidate_x - start_pos[0], 2) + pow(candidate_y - start_pos[1], 2))
		#print(distance)
		# Altrimenti, tieni traccia della migliore posizione trovata finora
		if distance > best_distance:
			best_distance = distance
			best_end_x = candidate_x
			best_end_y = candidate_y
		
	# Se non è stata trovata una posizione ideale, usa la migliore disponibile
	if best_end_x != -1 and best_end_y != -1:
		end_pos[0] = best_end_x
		end_pos[1] = best_end_y
		map[end_pos[1]][end_pos[0]] = 'E'
	else:
		GlobalVariables.d_error("Errore nel trovare una posizione di uscita valida", "MAP_GENERATION")
	#print(max_attempts)

# Funzione generica per trovare posizioni valide
static func find_valid_position(map: Array, width: int, height: int, start_x: int, start_y: int, end_x: int, end_y: int, max_attempts: int = 50) -> Vector2i:
	for attempts in range(max_attempts):
		var x = 1 + randi() % (width - 2)
		var y = 1 + randi() % (height - 2)
		if map[y][x] == MapConstants.TERRAIN.ICE and not (x == start_x and y == start_y) and not (x == end_x and y == end_y):
			return Vector2i(x, y)
	return Vector2i(-1, -1)

# Funzione generica per aggiungere terreno con callback opzionale
static func add_terrain_generic(map: Array, count: int, start_x: int, start_y: int, end_x: int, end_y: int, max_attempts: int = 50, callback: Callable = Callable()):
	var width = map[0].size()
	var height = map.size()
		
	for i in range(count):
		var pos = find_valid_position(map, width, height, start_x, start_y, end_x, end_y, max_attempts)
		if pos != Vector2i(-1, -1):
			if callback.is_valid():
				callback.call(map, pos.x, pos.y, width, height)

# Funzioni callback per diversi tipi di terreno
static func place_normal_terrain(map: Array, x: int, y: int, _width: int, _height: int):
	map[y][x] = MapConstants.TERRAIN.NORMAL

static func place_fragile_ice(map: Array, x: int, y: int, _width: int, _height: int):
	map[y][x] = MapConstants.TERRAIN.FRAGILE_ICE

static func place_deadly_hole(map: Array, x: int, y: int, _width: int, _height: int):
	map[y][x] = MapConstants.TERRAIN.HOLE

static func place_obstacle(map: Array, x: int, y: int, width: int, height: int):
	var obstacle_size = 1 + randi() % 3
		
	for dy in range(obstacle_size):
		if y + dy >= height - 1:
			break
		for dx in range(obstacle_size):
			if x + dx >= width - 1:
				break
			if map[y + dy][x + dx] == MapConstants.TERRAIN.ICE:
				map[y + dy][x + dx] = MapConstants.TERRAIN.WALL

static func place_conveyor_belt(map: Array, x: int, y: int, width: int, height: int):
	var valid_directions = []
		
	for dir in range(4):
		var target_x = x + MapConstants.DIRECTION_VECTORS[dir][0]
		var target_y = y + MapConstants.DIRECTION_VECTORS[dir][1]
		
		if MapTerrain.is_valid_position(target_x, target_y, width, height) and not MapTerrain.is_wall(map, target_x, target_y):
			valid_directions.append(dir + 1)
		
	if not valid_directions.is_empty():
		var random_index = randi() % valid_directions.size()
		var direction = valid_directions[random_index]
		map[y][x] = str(direction)

# Funzioni ottimizzate per aggiungere terreni specifici
static func add_normal_terrain(map: Array, difficulty: int, start_x: int, start_y: int, end_x: int, end_y: int):
	var width = map[0].size()
	var height = map.size()
	var count = (width * height) / (15 + difficulty * 5)
	add_terrain_generic(map, count, start_x, start_y, end_x, end_y, 50, place_normal_terrain)

# molti ammassi di muri
static func add_obstacles(map: Array, difficulty: int, start_x: int, start_y: int, end_x: int, end_y: int):
	var width = map[0].size()
	var height = map.size()
	var count = difficulty * 5 + (width * height) / 25
	add_terrain_generic(map, count, start_x, start_y, end_x, end_y, 100, place_obstacle)

# singoli muri sparsi
static func add_scattered_walls(map: Array):
	var width = map[0].size()
	var height = map.size()
	var count = (width * height) / 8
		
	for i in range(count):
		var x = 1 + randi() % (width - 2)
		var y = 1 + randi() % (height - 2)
		if map[y][x] == MapConstants.TERRAIN.ICE:
			map[y][x] = MapConstants.TERRAIN.WALL

static func add_deadly_holes(map: Array, difficulty: int, start_x: int, start_y: int, end_x: int, end_y: int):
	if difficulty < 4:
		return
		
	var width = map[0].size()
	var height = map.size()
	var count = (difficulty - 2) * 2 + (width * height) / 100
	add_terrain_generic(map, count, start_x, start_y, end_x, end_y, 50, place_deadly_hole)

static func add_fragile_ice(map: Array, difficulty: int, start_x: int, start_y: int, end_x: int, end_y: int):
	if difficulty < 2:
		return
		
	var width = map[0].size()
	var height = map.size()
	var count = (difficulty - 1) * 3 + (width * height) / 80
	add_terrain_generic(map, count, start_x, start_y, end_x, end_y, 50, place_fragile_ice)

static func add_conveyor_belts(map: Array, difficulty: int, start_x: int, start_y: int, end_x: int, end_y: int):
	if difficulty < 3:
		return
		
	var width = map[0].size()
	var height = map.size()
	var count = (difficulty) * 2 + (width * height) / 120
	add_terrain_generic(map, count, start_x, start_y, end_x, end_y, 50, place_conveyor_belt)

static func generate_single_map(width: int, height: int, difficulty: int, positions: Array) -> Array:
	var map = create_empty_map(width, height)
	var start_pos = [0, 0]
	var end_pos = [0, 0]
		
	place_start_and_end(map, start_pos, end_pos)
	positions[0] = start_pos[0]  # start_x
	positions[1] = start_pos[1]  # start_y
	positions[2] = end_pos[0]	# end_x
	positions[3] = end_pos[1]	# end_y
		
	add_normal_terrain(map, difficulty, start_pos[0], start_pos[1], end_pos[0], end_pos[1])
	add_obstacles(map, difficulty, start_pos[0], start_pos[1], end_pos[0], end_pos[1])
	add_scattered_walls(map)
	add_fragile_ice(map, difficulty, start_pos[0], start_pos[1], end_pos[0], end_pos[1])
	add_conveyor_belts(map, difficulty, start_pos[0], start_pos[1], end_pos[0], end_pos[1])
	add_deadly_holes(map, difficulty, start_pos[0], start_pos[1], end_pos[0], end_pos[1])
		
	return map
