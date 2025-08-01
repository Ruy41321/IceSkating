class_name MapIO

# === SALVATAGGIO MAPPE ===

static func save_map_to_file(filename: String, map: Array, difficulty: int, result: MapPathfinding.PathResult, width: int, height: int) -> bool:
    var full_path = _prepare_save_path(filename)
    if full_path.is_empty():
        return false
    
    var file = FileAccess.open(full_path, FileAccess.WRITE)
    if file == null:
        GlobalVariables.d_error("Errore: impossibile creare il file " + str(full_path), "MAP_IO")
        return false
    
    _write_file_content(file, map, difficulty, result, width, height)
    file.close()
    
    GlobalVariables.d_info("Mappa salvata in: " + str(full_path), "MAP_IO")
    return true

static func _prepare_save_path(filename: String) -> String:
    var maps_dir = "user://maps/"
    var full_path = maps_dir + filename
    
    if not full_path.ends_with(".map"):
        full_path += ".map"
    
    if not _ensure_directory_exists(maps_dir):
        return ""
    
    return full_path

static func _ensure_directory_exists(maps_dir: String) -> bool:
    if DirAccess.dir_exists_absolute(maps_dir):
        return true
    
    var dir = DirAccess.open("user://")
    if dir == null:
        GlobalVariables.d_error("Errore: impossibile accedere alla directory user://", "FILE_SYSTEM")
        return false
    
    var error = dir.make_dir("maps")
    if error == OK:
        GlobalVariables.d_info("Cartella maps/ creata con successo in: " + str(ProjectSettings.globalize_path(maps_dir)), "FILE_SYSTEM")
        return true
    else:
        GlobalVariables.d_error("Errore nella creazione della cartella maps/: " + str(error), "FILE_SYSTEM")
        return false

static func _write_file_content(file: FileAccess, map: Array, difficulty: int, result: MapPathfinding.PathResult, width: int, height: int):
    # Header con informazioni
    file.store_line("# Mappa generata con difficolta: " + str(difficulty))
    file.store_line(_get_terrain_description(difficulty))
    file.store_line("# Mosse minime richieste (cambi direzione): " + str(result.min_moves))
    file.store_line("# Mosse totali nella sequenza: " + str(result.full_path.size()))
    file.store_line(_build_move_sequence(result.full_path))
    
    # Metadati
    file.store_line("width=" + str(width))
    file.store_line("height=" + str(height))
    file.store_line("difficulty=" + str(difficulty))
    file.store_line("min_moves=" + str(result.min_moves))
    file.store_line("total_moves=" + str(result.full_path.size()))
    file.store_line("")
    
    # Griglia della mappa
    for y in range(height):
        var line = ""
        for x in range(width):
            line += map[y][x]
        file.store_line(line)

static func _get_terrain_description(difficulty: int) -> String:
    var desc = "# Terreni: M=Muro, G=Ghiaccio, T=Terreno normale, I=Ingresso, E=Uscita"
    
    if difficulty >= 2:
        desc += ", D=Ghiaccio fragile (si rompe dopo 1 passaggio)"
    if difficulty >= 3:
        desc += ", B=Buco (mortale)"
    if difficulty >= 4:
        desc += ", 1234=Nastri trasportatori (1=destra, 2=sinistra, 3=giù, 4=su)"
    
    return desc

static func _build_move_sequence(path: Array) -> String:
    var sequence_str = "# Sequenza completa: "
    
    for i in range(path.size()):
        if i > 0:
            sequence_str += " -> "
        sequence_str += MapConstants.direction_to_string(path[i])
    
    return sequence_str

# === CARICAMENTO MAPPE ===

static func get_map_from_file(filepath: String, positions: Array) -> Array:
    var full_path = "res://maps/" + filepath + ".map"
    var file = FileAccess.open(full_path, FileAccess.READ)
    
    if file == null:
        GlobalVariables.d_error("Errore: impossibile aprire il file " + str(full_path), "MAP_IO")
        return []
    
    var map_data = _parse_map_file(file)
    file.close()
    
    if not _validate_map_data(map_data):
        return []
    
    _populate_positions_array(positions, map_data)
    _print_load_success(map_data)
    
    return map_data.map

static func _parse_map_file(file: FileAccess) -> Dictionary:
    var map_data = {
        "map": [],
        "start_x": -1,
        "start_y": -1,
        "end_x": -1,
        "end_y": -1
    }
    
    while not file.eof_reached():
        var line = file.get_line().strip_edges()
        
        # Salta linee vuote, commenti e metadati
        if line.is_empty() or line.begins_with("#") or line.contains("="):
            continue
        
        _process_grid_line(line, map_data)
    
    return map_data

static func _process_grid_line(line: String, map_data: Dictionary):
    var row = []
    var current_y = map_data.map.size()
    
    for i in range(line.length()):
        var ch = line[i]
        row.append(ch)
        
        # Trova posizioni speciali
        if ch == MapConstants.TERRAIN.START:
            map_data.start_x = i
            map_data.start_y = current_y
        elif ch == MapConstants.TERRAIN.END:
            map_data.end_x = i
            map_data.end_y = current_y
    
    if not row.is_empty():
        map_data.map.append(row)

static func _validate_map_data(map_data: Dictionary) -> bool:
    if map_data.map.is_empty():
        GlobalVariables.d_error("Errore: mappa vuota", "MAP_VALIDATION")
        return false
    
    if map_data.start_x == -1 or map_data.start_y == -1:
        GlobalVariables.d_error("Errore: ingresso (I) non trovato nella mappa", "MAP_VALIDATION")
        return false
    
    if map_data.end_x == -1 or map_data.end_y == -1:
        GlobalVariables.d_error("Errore: uscita (E) non trovata nella mappa", "MAP_VALIDATION")
        return false
    
    return true

static func _populate_positions_array(positions: Array, map_data: Dictionary):
    positions[0] = map_data.start_x
    positions[1] = map_data.start_y
    positions[2] = map_data.end_x
    positions[3] = map_data.end_y

static func _print_load_success(map_data: Dictionary):
    GlobalVariables.d_info("Mappa caricata con successo:", "MAP_IO")
    GlobalVariables.d_info("- Dimensioni: " + str(map_data.map[0].size()) + "x" + str(map_data.map.size()), "MAP_IO")
    GlobalVariables.d_info("- Ingresso: (" + str(map_data.start_x) + "," + str(map_data.start_y) + ")", "MAP_IO")
    GlobalVariables.d_info("- Uscita: (" + str(map_data.end_x) + "," + str(map_data.end_y) + ")", "MAP_IO")

# === UTILITÀ ===

static func map_exists(filename: String) -> bool:
    var full_path = "res://maps/" + filename
    if not full_path.ends_with(".map"):
        full_path += ".map"
    return FileAccess.file_exists(full_path)

static func get_available_maps() -> Array[String]:
    var maps = []
    var dir = DirAccess.open("res://maps/")
    
    if dir != null:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        
        while file_name != "":
            if file_name.ends_with(".map"):
                maps.append(file_name.get_basename())
            file_name = dir.get_next()
    
    return maps