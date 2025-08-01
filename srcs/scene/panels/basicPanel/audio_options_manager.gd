class_name AudioOptionsManager
extends RefCounted

"""
Gestore delle opzioni audio per il BasicPanel.
Gestisce la creazione, visualizzazione e persistenza delle impostazioni audio.
"""

#region CONSTANTS

const CONFIG_FILE_PATH = "user://settings.cfg"
const AUDIO_SETTINGS_SECTION = "audio_settings"

#endregion

#region VOLUME SLIDERS

static var master_slider: HSlider
static var sfx_slider: HSlider
static var ui_slider: HSlider
static var music_slider: HSlider

#endregion

#region INITIALIZATION

static func setup_volume_controls() -> void:
	"""Crea i controlli del volume dinamicamente"""
	# Crea gli slider del volume solo se non esistono già
	if not master_slider:
		master_slider = _create_volume_slider(AudioManager.master_volume)
		master_slider.value_changed.connect(_on_master_volume_changed)
	
	if not sfx_slider:
		sfx_slider = _create_volume_slider(AudioManager.sfx_volume)
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if not ui_slider:
		ui_slider = _create_volume_slider(AudioManager.ui_volume)
		ui_slider.value_changed.connect(_on_ui_volume_changed)
	
	if not music_slider:
		music_slider = _create_volume_slider(AudioManager.music_volume)
		music_slider.value_changed.connect(_on_music_volume_changed)

static func _create_volume_slider(initial_value: float) -> HSlider:
	"""Crea un singolo slider per il volume"""
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial_value
	slider.custom_minimum_size = Vector2(300, 30)
	
	# Assicurati che sia interattivo
	slider.mouse_filter = Control.MOUSE_FILTER_PASS
	slider.focus_mode = Control.FOCUS_ALL
	slider.editable = true
	
	return slider

static func recreate_sliders_if_needed() -> void:
	"""Ricrea gli slider se sono stati eliminati durante il cambio lingua"""
	# Controlla se gli slider sono ancora validi
	if not is_instance_valid(master_slider):
		master_slider = _create_volume_slider(AudioManager.master_volume)
		# Connetti solo se non è già connesso
		if not master_slider.value_changed.is_connected(_on_master_volume_changed):
			master_slider.value_changed.connect(_on_master_volume_changed)
	
	if not is_instance_valid(sfx_slider):
		sfx_slider = _create_volume_slider(AudioManager.sfx_volume)
		if not sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
			sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if not is_instance_valid(ui_slider):
		ui_slider = _create_volume_slider(AudioManager.ui_volume)
		if not ui_slider.value_changed.is_connected(_on_ui_volume_changed):
			ui_slider.value_changed.connect(_on_ui_volume_changed)
	
	if not is_instance_valid(music_slider):
		music_slider = _create_volume_slider(AudioManager.music_volume)
		if not music_slider.value_changed.is_connected(_on_music_volume_changed):
			music_slider.value_changed.connect(_on_music_volume_changed)

#endregion

#region UI CREATION

static func create_options_ui(parent_container: VBoxContainer) -> void:
	"""Configura l'interfaccia delle opzioni con slider interattivi"""
	# Pulisce il container se ha già dei figli (per aggiornare i testi localizzati)
	for child in parent_container.get_children():
		child.queue_free()
	
	# Aspetta che i nodi vengano rimossi completamente
	if parent_container.get_child_count() > 0:
		await parent_container.get_tree().process_frame
	
	# Ricrea gli slider se sono stati eliminati durante il cambio lingua
	recreate_sliders_if_needed()
	
	# Titolo
	var title_label = RichTextLabel.new()
	title_label.text = "[center][b]" + LocalizationManager.get_text("options_title") + "[/b][/center]"
	title_label.fit_content = true
	title_label.custom_minimum_size = Vector2(400, 40)
	title_label.bbcode_enabled = true
	parent_container.add_child(title_label)
	
	# Spacing
	parent_container.add_child(_create_spacer(10))
	
	# Master Volume
	parent_container.add_child(_create_volume_control_group("options_master_volume", master_slider))
	parent_container.add_child(_create_spacer(5))
	
	# SFX Volume
	parent_container.add_child(_create_volume_control_group("options_sfx_volume", sfx_slider))
	parent_container.add_child(_create_spacer(5))
	
	# UI Volume
	parent_container.add_child(_create_volume_control_group("options_ui_volume", ui_slider))
	parent_container.add_child(_create_spacer(5))
	
	# Music Volume
	parent_container.add_child(_create_volume_control_group("options_music_volume", music_slider))
	parent_container.add_child(_create_spacer(10))

static func _create_volume_control_group(label_key: String, slider: HSlider) -> VBoxContainer:
	"""Crea un gruppo controllo volume con etichetta e slider"""
	var group = VBoxContainer.new()
	group.set_h_size_flags(Control.SIZE_SHRINK_CENTER)
	
	# Etichetta
	var label = RichTextLabel.new()
	label.text = "[b]" + LocalizationManager.get_text(label_key) + "[/b]"
	label.fit_content = true
	label.custom_minimum_size = Vector2(300, 25)
	label.bbcode_enabled = true
	group.add_child(label)
	
	# Container orizzontale per slider e valore
	var h_container = HBoxContainer.new()
	
	# Slider
	h_container.add_child(slider)
	
	# Etichetta valore
	var value_label = Label.new()
	value_label.text = str(int(slider.value * 100)) + "%"
	value_label.custom_minimum_size = Vector2(50, 30)
	h_container.add_child(value_label)
	
	# Disconnetti eventuali connessioni precedenti per il display del valore
	# per evitare accumulo di callback durante la ricreazione dell'UI
	var connections = slider.value_changed.get_connections()
	for connection in connections:
		# Rimuovi solo le connessioni che sembrano essere per il display del valore
		# (le connessioni vere per il volume control sono in _on_*_volume_changed)
		var callable_object = connection.callable.get_object()
		if callable_object == null:  # Callback anonimo/lambda
			slider.value_changed.disconnect(connection.callable)
	
	# Connetti il nuovo callback per aggiornare l'etichetta
	slider.value_changed.connect(func(value): value_label.text = str(int(value * 100)) + "%")
	
	group.add_child(h_container)
	return group

static func _create_spacer(height: int) -> Control:
	"""Crea uno spacer verticale"""
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

static func update_slider_values() -> void:
	"""Aggiorna i valori degli slider con i valori correnti dell'audio"""
	# Verifica che gli slider esistano prima di aggiornarli
	if master_slider and is_instance_valid(master_slider):
		master_slider.value = AudioManager.master_volume
	if sfx_slider and is_instance_valid(sfx_slider):
		sfx_slider.value = AudioManager.sfx_volume
	if ui_slider and is_instance_valid(ui_slider):
		ui_slider.value = AudioManager.ui_volume
	if music_slider and is_instance_valid(music_slider):
		music_slider.value = AudioManager.music_volume

#endregion

#region SETTINGS PERSISTENCE

static func load_saved_volume_settings() -> void:
	"""Carica le impostazioni del volume salvate dal file di configurazione"""
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)
	
	if err == OK:
		# Carica i valori salvati o usa i default se non esistono
		var master_vol = config.get_value(AUDIO_SETTINGS_SECTION, "master_volume", AudioManager.master_volume)
		var sfx_vol = config.get_value(AUDIO_SETTINGS_SECTION, "sfx_volume", AudioManager.sfx_volume)
		var ui_vol = config.get_value(AUDIO_SETTINGS_SECTION, "ui_volume", AudioManager.ui_volume)
		var music_vol = config.get_value(AUDIO_SETTINGS_SECTION, "music_volume", AudioManager.music_volume)
		
		# Applica i volumi caricati all'AudioManager
		AudioManager.set_master_volume(master_vol)
		AudioManager.set_sfx_volume(sfx_vol)
		AudioManager.set_ui_volume(ui_vol)
		AudioManager.set_music_volume(music_vol)
		
		# Aggiorna gli slider se esistono già
		update_slider_values()
		
		GlobalVariables.d_info("Volume settings loaded from config", "AUDIO")
	else:
		GlobalVariables.d_info("No volume settings found, using defaults", "AUDIO")

static func save_volume_settings() -> void:
	"""Salva le impostazioni del volume correnti nel file di configurazione"""
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE_PATH)  # Carica eventuali impostazioni esistenti
	
	# Se il caricamento fallisce, inizializza comunque il ConfigFile vuoto
	# ma non sovrascrivere le impostazioni esistenti se il file esiste
	if err != OK:
		GlobalVariables.d_info("Could not load existing config, creating new one", "AUDIO")
	
	# Salva i valori correnti del volume nella sezione audio_settings
	config.set_value(AUDIO_SETTINGS_SECTION, "master_volume", AudioManager.master_volume)
	config.set_value(AUDIO_SETTINGS_SECTION, "sfx_volume", AudioManager.sfx_volume)
	config.set_value(AUDIO_SETTINGS_SECTION, "ui_volume", AudioManager.ui_volume)
	config.set_value(AUDIO_SETTINGS_SECTION, "music_volume", AudioManager.music_volume)
	
	# Salva il file mantenendo tutte le altre sezioni intatte
	var save_err = config.save(CONFIG_FILE_PATH)
	if save_err == OK:
		GlobalVariables.d_verbose("Volume settings saved to config", "AUDIO")
	else:
		GlobalVariables.d_error("Failed to save volume settings: " + str(save_err), "AUDIO")

#endregion

#region VOLUME CONTROL CALLBACKS

static func _on_master_volume_changed(value: float) -> void:
	"""Callback per il cambio del volume master"""
	AudioManager.set_master_volume(value)
	save_volume_settings()

static func _on_sfx_volume_changed(value: float) -> void:
	"""Callback per il cambio del volume SFX"""
	AudioManager.set_sfx_volume(value)
	AudioManager.play_game_sfx("wall_collision")  # Test SFX
	save_volume_settings()

static func _on_ui_volume_changed(value: float) -> void:
	"""Callback per il cambio del volume UI"""
	AudioManager.set_ui_volume(value)
	AudioManager.play_ui_sound("click")  # Test UI sound
	save_volume_settings()

static func _on_music_volume_changed(value: float) -> void:
	"""Callback per il cambio del volume musica"""
	AudioManager.set_music_volume(value)
	save_volume_settings()

#endregion
