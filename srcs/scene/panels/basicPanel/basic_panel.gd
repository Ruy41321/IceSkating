extends Control

@onready var credits_label: RichTextLabel = $WindowsSprite/AspectRatioContainer/CreditsLabel
@onready var info_label: RichTextLabel = $WindowsSprite/AspectRatioContainer/InfoLabel
@onready var leaderboard: RichTextLabel = $WindowsSprite/AspectRatioContainer/Leaderboard
@onready var close_button: TextureButton = $WindowsSprite/CloseSettingsPanelButton

# Container per le opzioni (creato dinamicamente)
var options_container: VBoxContainer
var options_ui_initialized: bool = false

func _ready() -> void:
	setup_signals()
	setup_localization()
	AudioOptionsManager.load_saved_volume_settings()  # Carica prima le impostazioni
	AudioOptionsManager.setup_volume_controls()       # Poi crea i controlli con i valori corretti

func setup_localization() -> void:
	"""Configura il sistema di localizzazione"""
	# Connetti al segnale di cambio lingua
	LocalizationManager.language_changed.connect(_on_language_changed)

func _on_language_changed(_new_language: String) -> void:
	"""Chiamata quando cambia la lingua"""
	# Resetta il flag di inizializzazione per permettere ricreazione con nuovi testi
	options_ui_initialized = false
	
	# Se un pannello è attualmente visibile, aggiorna il suo contenuto
	if not self.visible:
		return
	elif credits_label.visible:
		show_credits()
	elif info_label.visible:
		show_info()
	elif leaderboard.visible:
		# Ricarica l'ultima leaderboard mostrata (default ranked se non specificato)
		show_leaderboard("ranked")
	elif options_container and options_container.visible:
		show_option()

func setup_signals() -> void:
	close_button.pressed.connect(_on_close_button_pressed)

func _on_close_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	credits_label.hide()
	info_label.hide()
	leaderboard.hide()
	if options_container:
		options_container.hide()
	self.hide()

func show_credits() -> void:
	AudioManager.play_ui_sound("click")
	credits_label.show()
	info_label.hide()
	leaderboard.hide()
	if options_container:
		options_container.hide()
	
	# Aggiorna il contenuto dei crediti con la lingua corrente
	credits_label.text = "[center][b]" + LocalizationManager.get_text("credits_title") + "[/b][/center]

[b]" + LocalizationManager.get_text("credits_executive_producer") + "[/b]
Luigi Pennisi

[b]" + LocalizationManager.get_text("credits_game_mechanics") + "[/b]
Luigi Pennisi

[b]" + LocalizationManager.get_text("credits_artist") + "[/b]
Giuseppe Vigilante

[center]" + LocalizationManager.get_text("credits_thanks") + "[/center]"
	
	show()

func show_info() -> void:
	AudioManager.play_ui_sound("click")
	credits_label.hide()
	leaderboard.hide()
	if options_container:
		options_container.hide()
	
	# Aggiorna il contenuto delle info con la lingua corrente
	info_label.text = "[center][b]" + LocalizationManager.get_text("info_title") + "[/b][/center]

[b]" + LocalizationManager.get_text("info_objective") + "[/b]
" + LocalizationManager.get_text("info_objective_text") + "

[b]" + LocalizationManager.get_text("info_controls") + "[/b]
• [b]" + LocalizationManager.get_text("info_pc_movement") + "[/b]
• [b]" + LocalizationManager.get_text("info_pc_menu") + "[/b]
• [b]" + LocalizationManager.get_text("info_mobile_movement") + "[/b]
• [b]" + LocalizationManager.get_text("info_mobile_menu") + "[/b]

[center]" + LocalizationManager.get_text("info_good_luck") + "[/center]"
	
	info_label.show()
	show()

func show_leaderboard(leaderboard_type: String = "ranked") -> void:
	AudioManager.play_ui_sound("click")
	info_label.hide()
	credits_label.hide()
	if options_container:
		options_container.hide()
	
	# Imposta testo di caricamento localizzato
	var title_key = "leaderboard_title" if leaderboard_type == "ranked" else "leaderboard_levels_title"
	leaderboard.text = "[center][b]" + LocalizationManager.get_text(title_key) + "[/b][/center]\n\n[center]" + LocalizationManager.get_text("leaderboard_loading") + "[/center]"
	leaderboard.show()
	show()
	
	# Carica i dati della leaderboard appropriata
	var leaderboard_data: Dictionary
	if leaderboard_type == "levels":
		leaderboard_data = await GameAPI.get_levels_leaderboard(20)  # Top 20 giocatori per livelli
	else:
		leaderboard_data = await GameAPI.get_leaderboard(20)  # Top 20 giocatori per punteggio
	
	if leaderboard_data.success:
		_display_leaderboard(leaderboard_data.leaderboard, leaderboard_type)
	else:
		var error_title = LocalizationManager.get_text(title_key)
		leaderboard.text = "[center][b]" + error_title + "[/b][/center]\n\n[center][color=red]" + LocalizationManager.get_text("leaderboard_error") + "[/color][/center]"

func show_option() -> void:
	"""Mostra il pannello delle opzioni audio"""
	AudioManager.play_ui_sound("click")
	info_label.hide()
	credits_label.hide()
	leaderboard.hide()
	
	# Nascondi prima il container per evitare problemi di visualizzazione
	if options_container:
		options_container.hide()
	
	# Setup dell'interfaccia options
	_setup_options_ui()
	
	# Mostra il container delle opzioni
	options_container.show()
	show()

func _setup_options_ui() -> void:
	"""Configura l'interfaccia delle opzioni con slider interattivi"""
	# Se l'UI è già stata inizializzata, aggiorna solo i valori
	if options_ui_initialized:
		AudioOptionsManager.update_slider_values()
		return
	
	# Assicurati che il container esista
	if not options_container:
		options_container = VBoxContainer.new()
		options_container.name = "OptionsContainer"
	
	# Se il container non è già stato aggiunto, lo aggiungiamo
	if not options_container.get_parent():
		# Trova il parent corretto (AspectRatioContainer)
		var aspect_container = $WindowsSprite/AspectRatioContainer
		aspect_container.add_child(options_container)
	
	# Crea l'interfaccia delle opzioni utilizzando il manager
	await AudioOptionsManager.create_options_ui(options_container)
	
	# Marca come inizializzato
	options_ui_initialized = true

func _display_leaderboard(leaderboard_array: Array, leaderboard_type: String = "ranked") -> void:
	var title_key = "leaderboard_title" if leaderboard_type == "ranked" else "leaderboard_levels_title"
	leaderboard.text = "[center][b]" + LocalizationManager.get_text(title_key) + "[/b][/center]\n\n"
	
	if leaderboard_array.is_empty():
		leaderboard.text += "[center]" + LocalizationManager.get_text("leaderboard_empty") + "[/center]"
		return
	
	# Header localizzato in base al tipo di leaderboard
	if leaderboard_type == "levels":
		leaderboard.text += "[b]" + LocalizationManager.get_text("leaderboard_position") + "    " + LocalizationManager.get_text("leaderboard_name") + "            " + LocalizationManager.get_text("leaderboard_levels_completed") + "[/b]\n"
	else:
		leaderboard.text += "[b]" + LocalizationManager.get_text("leaderboard_position") + "    " + LocalizationManager.get_text("leaderboard_name") + "            " + LocalizationManager.get_text("leaderboard_best_score") + "[/b]\n"
	
	leaderboard.text += "─────────────────────────────────────\n"
	
	# Dati giocatori
	for i in range(leaderboard_array.size()):
		var player = leaderboard_array[i]
		var rank = player.get("position", 0)
		var pos = str(rank).pad_zeros(2)
		pos = pos.rpad(3)
		var username = player.get("username", "Unknown")
		if username.length() > 15:
			username = username.substr(0, 15)
		username = username.rpad(17)
		
		var score_value: String
		if leaderboard_type == "levels":
			score_value = str(player.get("map_completed", 0))
		else:
			score_value = str(player.get("best_score", 0))
		
		if score_value == "0":
			continue

		score_value = score_value.rpad(5)
		# Evidenzia le prime 3 posizioni
		if rank == 1:
			leaderboard.text += "[color=gold]🥇 " + pos + "  " + username + "  " + score_value + "[/color]\n"
		elif rank == 2:
			leaderboard.text += "[color=silver]🥈 " + pos + "  " + username + "  " + score_value + "[/color]\n"
		elif rank == 3:
			leaderboard.text += "[color=#CD7F32]🥉 " + pos + "  " + username + "  " + score_value + "[/color]\n"
		else:
			leaderboard.text += "   " + pos + "  " + username + "  " + score_value + "\n"
