class_name Map_gen
extends Node

# Parametri di difficoltà
var min_moves: int
var max_moves: int

# Funzione principale di generazione
func generate_map(map_name: String, difficulty: String) -> int:
    var difficulty_level = difficulty.to_int()
        
    if not _is_valid_difficulty(difficulty_level):
        GlobalVariables.d_error("Errore: la difficoltà deve essere tra 1 e 5.", "MAP_GENERATION")
        return -1
    
    var config = _get_difficulty_config(difficulty_level)
    var map_data = _generate_valid_map(config)
    
    if map_data.error_code != 0:
        return map_data.error_code
    
    # Salva la mappa
    MapIO.save_map_to_file(map_name, map_data.map, difficulty_level, map_data.result, map_data.width, map_data.height)
    
    _print_generation_success(map_data.attempts, map_data.result.min_moves)
    return 0

func test_map(map_name: String):
    var positions = [0, 0, 0, 0]
    var map = MapIO.get_map_from_file(map_name, positions)
    
    if map.is_empty():
        GlobalVariables.d_error("Errore: impossibile caricare la mappa.", "MAP_MANAGEMENT")
        return
    
    var result = MapPathfinding.calculate_min_moves_and_path(map, positions[0], positions[1], positions[2], positions[3], 999)
    _print_move_sequence(result)

# Funzioni private di supporto
func _is_valid_difficulty(difficulty: int) -> bool:
    return difficulty >= 1 and difficulty <= 5

func _get_difficulty_config(difficulty_level: int) -> Dictionary:
    return {
        "min_size": 10 + difficulty_level * 8,
        "max_size": 15 + difficulty_level * 8,
        "min_moves": difficulty_level * 5 + 6,
        "max_moves": (difficulty_level + 1) * 5 + 8,
        "max_attempts": 1000,
        "difficulty": difficulty_level
    }

func _generate_valid_map(config: Dictionary) -> Dictionary:
    min_moves = config.min_moves
    max_moves = config.max_moves
    
    var width = config.min_size + (randi() % (config.max_size - config.min_size + 1))
    var height = config.min_size + (randi() % (config.max_size - config.min_size + 1))
    
    var attempts = 0
    var positions = [0, 0, 0, 0]
    
    while attempts < config.max_attempts:
        attempts += 1
        
        if attempts % 100 == 0:
            GlobalVariables.d_debug("Tentativo " + str(attempts) + "/" + str(config.max_attempts) + "...", "MAP_GENERATION")
        
        var map = MapGeneration.generate_single_map(width, height, config.difficulty, positions)
        var result = MapPathfinding.calculate_min_moves_and_path(map, positions[0], positions[1], positions[2], positions[3], max_moves)
        
        if result.min_moves == -1:
            continue
            
        if _is_valid_move_count(result.min_moves):
            return {
                "map": map,
                "result": result,
                "width": width,
                "height": height,
                "attempts": attempts,
                "error_code": 0
            }
    
    GlobalVariables.d_error("Errore: impossibile generare una mappa valida dopo " + str(config.max_attempts) + " tentativi.", "MAP_GENERATION")
    return {"error_code": -104}

func _is_valid_move_count(moves: int) -> bool:
    return moves >= min_moves and moves <= max_moves

func _print_generation_success(attempts: int, moves_found: int):
    GlobalVariables.d_info("Mappa valida trovata dopo " + str(attempts) + " tentativi.", "MAP_GENERATION")
    GlobalVariables.d_info("Numero minimo di mosse richieste: " + str(min_moves) + " (trovate " + str(moves_found) + ")", "MAP_GENERATION")

func _print_move_sequence(result: MapPathfinding.PathResult):
    GlobalVariables.d_debug("Sequenza completa di direzioni (" + str(result.full_path.size()) + " mosse totali):", "MAP_GENERATION")
    
    for i in range(result.full_path.size()):
        GlobalVariables.d_debug(str(i + 1) + ". " + MapConstants.direction_to_string(result.full_path[i]), "MAP_GENERATION")