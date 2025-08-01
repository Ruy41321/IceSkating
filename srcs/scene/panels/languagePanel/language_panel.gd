class_name LanguagePanel
extends Control

@onready var language_panel: Control = self
@onready var close_button: TextureButton = $PanelSprite/CloseSettingsPanelButton
@onready var language_container: VBoxContainer = $PanelSprite/AspectRatioContainer/LanguageContainer
@onready var title_label: Label = $PanelSprite/AspectRatioContainer/TitleLabel

var language_buttons: Array[Button] = []

func _ready() -> void:
	setup_signals()
	setup_language_buttons()
	update_texts()
	
	# Connetti al segnale di cambio lingua
	LocalizationManager.language_changed.connect(_on_language_changed)

func setup_signals() -> void:
	close_button.pressed.connect(_on_close_button_pressed)

func setup_language_buttons() -> void:
	"""Crea i pulsanti per ogni lingua disponibile"""
	# Rimuovi eventuali pulsanti esistenti
	for button in language_buttons:
		if button:
			button.queue_free()
	language_buttons.clear()
	
	# Crea un pulsante per ogni lingua disponibile
	for lang_code in LocalizationManager.get_available_languages():
		var button = Button.new()
		button.text = LocalizationManager.get_language_display_name(lang_code)
		button.pressed.connect(_on_language_button_pressed.bind(lang_code))
		
		# Evidenzia la lingua corrente
		if lang_code == LocalizationManager.get_current_language():
			button.modulate = Color.YELLOW
		
		language_container.add_child(button)
		language_buttons.append(button)

func _on_language_button_pressed(language_code: String) -> void:
	"""Cambia la lingua quando viene premuto un pulsante"""
	LocalizationManager.set_language(language_code)
	update_button_states()
	# Nascondi il pannello dopo aver selezionato la lingua
	hide()

func _on_language_changed(_new_language: String) -> void:
	"""Aggiorna l'interfaccia quando cambia la lingua"""
	update_texts()
	update_button_states()

func update_texts() -> void:
	"""Aggiorna tutti i testi con la lingua corrente"""
	title_label.text = LocalizationManager.get_text("language_title")
	
	# Aggiorna il testo dei pulsanti delle lingue
	for i in range(language_buttons.size()):
		if i < LocalizationManager.get_available_languages().size():
			var lang_code = LocalizationManager.get_available_languages()[i]
			language_buttons[i].text = LocalizationManager.get_language_display_name(lang_code)

func update_button_states() -> void:
	"""Aggiorna lo stato visivo dei pulsanti"""
	var current_lang = LocalizationManager.get_current_language()
	var available_langs = LocalizationManager.get_available_languages()
	
	for i in range(language_buttons.size()):
		if i < available_langs.size():
			var lang_code = available_langs[i]
			if lang_code == current_lang:
				language_buttons[i].modulate = Color.YELLOW
			else:
				language_buttons[i].modulate = Color.WHITE

func _on_close_button_pressed() -> void:
	hide()
