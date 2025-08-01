extends Camera2D

@onready var option_panel: Control = $CanvasLayer/OptionPanel

# Limiti della camera
var map_bounds: Dictionary = {}
var tile_size: int = 32  # Dimensione dei tile in pixel

func _ready() -> void:
	# Inizializza i limiti della camera quando diventa disponibile
	call_deferred("setup_camera_limits")

func setup_camera_limits() -> void:
	"""Configura i limiti della camera basandosi sui limiti della mappa"""
	if not _is_map_data_available():
		return
	
	map_bounds = _get_map_bounds()
	_apply_camera_limits()

func activate() -> void:
	# Attiva la camera
	enabled = true
	show()
	# Riaggiorna i limiti quando la camera viene attivata
	setup_camera_limits()

func deactivate() -> void:
	enabled = false
	hide()

func set_player_id(player_id: int) -> void:
	# Imposta l'ID del giocatore per il pannello delle opzioni
	option_panel.player_id = player_id

func _is_map_data_available() -> bool:
	"""Verifica se i dati della mappa sono disponibili"""
	var map_grid = MapManager.get_map_grid()
	return not map_grid.is_empty()

func _get_map_bounds() -> Dictionary:
	"""Ottiene i limiti della mappa dal MapManager"""
	var map_grid = MapManager.get_map_grid()
	if map_grid.is_empty():
		return {"width": 0, "height": 0}
	
	var map_height = map_grid.size()
	var map_width = map_grid[0].length() if map_height > 0 else 0
	return {"width": map_width, "height": map_height}

func _apply_camera_limits() -> void:
	"""Applica i limiti alla camera per impedire di inquadrare fuori dalla mappa"""
	if map_bounds.width == 0 or map_bounds.height == 0:
		return
	
	# Calcola i limiti in coordinate mondo (pixel)
	var map_pixel_width = map_bounds.width * tile_size
	var map_pixel_height = map_bounds.height * tile_size
	
	# Ottiene la dimensione della viewport
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_zoom = get_zoom()
	
	# Calcola la dimensione effettiva della vista con il zoom attuale
	var effective_view_width = viewport_size.x / camera_zoom.x
	var effective_view_height = viewport_size.y / camera_zoom.y
	
	# Imposta i limiti della camera
	# Se la mappa è più piccola della vista, centra la camera
	if not map_pixel_width <= effective_view_width:
		limit_left = 0
		limit_right = map_pixel_width

	if not map_pixel_height <= effective_view_height:
		limit_top = 0
		limit_bottom = map_pixel_height
	
	GlobalVariables.d_debug("Camera limits set: left=%d, right=%d, top=%d, bottom=%d for map %dx%d" % [limit_left, limit_right, limit_top, limit_bottom, map_bounds.width, map_bounds.height], "CAMERA")

func update_limits_on_zoom_change() -> void:
	"""Aggiorna i limiti quando cambia lo zoom della camera"""
	if map_bounds.has("width") and map_bounds.width > 0:
		_apply_camera_limits()
