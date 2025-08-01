class_name MapPathfinding

class PathResult:
	var min_moves: int
	var full_path: Array[int]
		
	func _init(moves: int = 0, path: Array[int] = []):
		min_moves = moves
		full_path = path

class DijkstraResult:
	var distance: Array
	var parent: Array
		
	func _init(dist: Array = [], par: Array = []):
		distance = dist
		parent = par

static func create_3d_array(width: int, height: int, depth: int, default_value = null):
	var array = []
	for y in range(height):
		var row = []
		for x in range(width):
			var dirs = []
			for d in range(depth):
				dirs.append(default_value)
			row.append(dirs)
		array.append(row)
	return array

static func run_dijkstra_search(map: Array, start_x: int, start_y: int, end_x: int, end_y: int, max_moves: int) -> DijkstraResult:
	var width = map[0].size()
	var height = map.size()
		
	var distance = create_3d_array(width, height, 5, -1)
	var parent = create_3d_array(width, height, 5, [-1, -1, -1])
		
	var broken_ice = {}

	var queue = [[start_x, start_y, MapConstants.DIRECTIONS.INITIAL, broken_ice]]
	distance[start_y][start_x][MapConstants.DIRECTIONS.INITIAL] = 0
		
	while not queue.is_empty():
		var current = queue.pop_front()
		var x = current[0]
		var y = current[1] 
		var last_dir = current[2]
		
		if x == end_x and y == end_y :
			#print("trovato percorso : ", distance[y][x][last_dir])
			return DijkstraResult.new(distance, parent)

		if distance[y][x][last_dir] > max_moves:
			#print("interrotto percorso troppo lungo")
			return null

		for i in range(4):
			var dir_vec = MapConstants.DIRECTION_VECTORS[i]
			var result = MapTerrain.simulate_move(map, current[3], x, y, dir_vec[0], dir_vec[1])
			
			var pos = result[0]  # result[0] è la nuova posizione dopo il movimento
			var new_ice_broken = result[1]  

			if (pos.x == x and pos.y == y) or MapTerrain.is_deadly_terrain(map, pos.x, pos.y) or new_ice_broken.has(pos):
				continue
			
			var move_cost = 1 if (last_dir == MapConstants.DIRECTIONS.INITIAL or last_dir != i) else 0
			var new_distance = distance[y][x][last_dir] + move_cost
			
			if distance[pos.y][pos.x][i] == -1 or distance[pos.y][pos.x][i] > new_distance:
				distance[pos.y][pos.x][i] = new_distance
				parent[pos.y][pos.x][i] = [x, y, last_dir]
				queue.append([pos.x, pos.y, i, result[1]])  # result[1] è l'asse del ghiaccio rotto
	#print("nessun percorso trovato")
	return null

static func find_best_final_direction(distance: Array, end_x: int, end_y: int) -> int:
	var best_dir = -1
	var min_moves = -1
		
	for dir in range(5):
		if distance[end_y][end_x][dir] != -1:
			if min_moves == -1 or distance[end_y][end_x][dir] < min_moves:
				min_moves = distance[end_y][end_x][dir]
				best_dir = dir
		
	return best_dir

static func reconstruct_full_move_path(parent: Array, _map: Array, start_x: int, start_y: int, end_x: int, end_y: int, best_dir: int) -> Array[int]:
	var path_states = []
	var trace_x = end_x
	var trace_y = end_y
	var trace_dir = best_dir
		
	while not (trace_x == start_x and trace_y == start_y and trace_dir == 4):
		path_states.append([trace_x, trace_y, trace_dir])
		var parent_info = parent[trace_y][trace_x][trace_dir]
		trace_x = parent_info[0]
		trace_y = parent_info[1]
		trace_dir = parent_info[2]
		
	path_states.reverse()
		
	var full_moves: Array[int] = []

	for state in path_states:
		full_moves.append(state[2])
		
	return full_moves

static func calculate_min_moves_and_path(map: Array, start_x: int, start_y: int, end_x: int, end_y: int, max_moves: int) -> PathResult:
	var search_result = run_dijkstra_search(map, start_x, start_y, end_x, end_y, max_moves)
	if search_result == null:
		return PathResult.new(-1, [])
	var distance = search_result.distance
	var parent = search_result.parent
		
	var best_dir = find_best_final_direction(distance, end_x, end_y)
		
	if best_dir == -1:
		return PathResult.new(-1, [])
		
	var min_moves = distance[end_y][end_x][best_dir]
	if min_moves != -1:
		var full_path = reconstruct_full_move_path(parent, map, start_x, start_y, end_x, end_y, best_dir)
		return PathResult.new(min_moves, full_path)
	else:
		return PathResult.new(-1, [])
