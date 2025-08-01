class_name AccountPanel
extends Control

const PASSWORD_SALT = "IceSkating2025_Salt"  # Aggiungi questa costante in cima al file

@onready var account_panel: Control = self
@onready var account_panel_close_button: TextureButton = $AccountPanel/CloseSettingsPanelButton
@onready var account_menu: Control = $AccountPanel/AspectRatioContainer/AccountMenu
@onready var login_button: Button = $AccountPanel/AspectRatioContainer/AccountMenu/LoginButton
@onready var register_button: Button = $AccountPanel/AspectRatioContainer/AccountMenu/RegisterButton
@onready var credential_form: Control = $AccountPanel/AspectRatioContainer/CredentialForm
@onready var username_line_edit: LineEdit = $AccountPanel/AspectRatioContainer/CredentialForm/UsernameLineEdit
@onready var password_line_edit: LineEdit = $AccountPanel/AspectRatioContainer/CredentialForm/PasswordLineEdit
@onready var credential_form_confirm_button: Button = $AccountPanel/AspectRatioContainer/CredentialForm/HBoxContainer/ConfirmButton
@onready var back_to_account_button: Button = $AccountPanel/AspectRatioContainer/CredentialForm/HBoxContainer/BackAccount
@onready var login_status_label: Label = $AccountPanel/LoginStatusLabel
@onready var player_stats: RichTextLabel = $AccountPanel/AspectRatioContainer/PlayerStats
@onready var logout_button: Button = $AccountPanel/AspectRatioContainer/LogoutButton

var wanna_login: bool = false #logging in or registering

signal trying_to_play_without_login

func _ready():
	setup_signals()
	setup_localization()
	
	# Controlla se l'utente è già loggato (auto-login)
	check_auto_login_status()

func setup_localization() -> void:
	"""Configura il sistema di localizzazione"""
	# Connetti al segnale di cambio lingua
	LocalizationManager.language_changed.connect(_on_language_changed)
	
	# Aggiorna i testi iniziali
	update_all_texts()

func _on_language_changed(_new_language: String) -> void:
	"""Chiamata quando cambia la lingua"""
	update_all_texts()
	
	# Se le statistiche del giocatore sono visibili, aggiornale anche
	if player_stats.visible and ClientManager.is_logged_in:
		update_player_stats_display()

func update_all_texts() -> void:
	"""Aggiorna tutti i testi dell'interfaccia"""
	# Pulsanti principali
	login_button.text = LocalizationManager.get_text("account_login")
	register_button.text = LocalizationManager.get_text("account_register")
	logout_button.text = LocalizationManager.get_text("account_logout")
	credential_form_confirm_button.text = LocalizationManager.get_text("account_submit")
	back_to_account_button.text = LocalizationManager.get_text("account_back")
	
	# Placeholder dei campi
	username_line_edit.placeholder_text = LocalizationManager.get_text("account_username")
	password_line_edit.placeholder_text = LocalizationManager.get_text("account_password")

func setup_signals() -> void:
	trying_to_play_without_login.connect(_on_trying_to_play_without_login)
	login_button.pressed.connect(_on_login_pressed)
	register_button.pressed.connect(_on_register_pressed)
	credential_form_confirm_button.pressed.connect(_on_credential_form_confirm_pressed)
	back_to_account_button.pressed.connect(_on_account_button_pressed)
	account_panel_close_button.pressed.connect(_on_account_panel_close_pressed)
	logout_button.pressed.connect(_on_logout_button_pressed)

	GameAPI.login_completed.connect(_on_login_completed)
	GameAPI.login_failed.connect(_on_login_failed)

func _on_logout_button_pressed() -> void:
	GameAPI.logout()  # Usa la funzione logout del GameAPI che pulisce tutto
	player_stats.hide()
	_on_account_button_pressed()

func _on_account_panel_close_pressed() -> void:
	GameAPI.is_logging_in = false
	self.hide()

func _on_trying_to_play_without_login():
	_on_account_button_pressed()
	login_status_label.text = LocalizationManager.get_text("account_login_required")
	login_status_label.show()
	self.show()
	
func _on_account_button_pressed() -> void:
	if self.visible:
		self.hide()
		return
	GameAPI.is_logging_in = false
	login_status_label.hide()
	credential_form.hide()
	if !ClientManager.is_logged_in:
		player_stats.hide()
		account_menu.show()
		username_line_edit.text = ""
		password_line_edit.text = ""
		logout_button.hide()
	else:
		# Se l'utente è già loggato (anche tramite auto-login), mostra le stats
		show_player_stats()
	self.show()

func _on_login_pressed() -> void:
	wanna_login = true
	account_menu.hide()
	credential_form.show()
	credential_form_confirm_button.disabled = false
	username_line_edit.text = ""
	password_line_edit.text = ""

func _on_register_pressed() -> void:
	wanna_login = false
	account_menu.hide()
	credential_form.show()
	credential_form_confirm_button.disabled = false
	username_line_edit.text = ""
	password_line_edit.text = ""

func md5_hash(input_string: String) -> String:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input_string.to_utf8_buffer())
	ctx.update((input_string + PASSWORD_SALT).to_utf8_buffer())
	var my_hash = ctx.finish()
	return my_hash.hex_encode()

func _on_credential_form_confirm_pressed() -> void:
	var encrypted_password: String

	if username_line_edit.text.strip_edges() == "" or password_line_edit.text.strip_edges() == "":
		login_status_label.text = LocalizationManager.get_text("account_empty_fields")
		login_status_label.show()
		return
	GameAPI.is_logging_in = true
	credential_form_confirm_button.disabled = true
	login_status_label.text = LocalizationManager.get_text("account_connecting")
	login_status_label.show()
	encrypted_password = md5_hash(password_line_edit.text)
	if wanna_login:
		GameAPI.login_user(username_line_edit.text, encrypted_password)
	else:
		GameAPI.register_user(username_line_edit.text, encrypted_password)
		
func _on_login_completed(success: bool, user_data: Dictionary, is_auto_login: bool) -> void:
	GameAPI.is_logging_in = false
	if success:
		ClientManager.user_data = user_data
		ClientManager.is_logged_in = true
		login_status_label.text = LocalizationManager.get_text("account_login_successful")
		login_status_label.hide()
		
		# Solo per login manuale, mostra le stats e apri il pannello
		if not is_auto_login:
			show_player_stats()
		else:
			# Per auto-login, prepara solo l'interfaccia senza aprire il pannello
			GlobalVariables.d_info("Auto-login completed, interface ready", "AUTHENTICATION")
	else:
		ClientManager.is_logged_in = false
		login_status_label.text = LocalizationManager.get_text("account_login_failed")
		login_status_label.show()
		credential_form_confirm_button.disabled = false

func _on_login_failed(error_message: String) -> void:
	GameAPI.is_logging_in = false
	ClientManager.is_logged_in = false
	login_status_label.text = error_message
	login_status_label.show()
	credential_form_confirm_button.disabled = false

func show_player_stats() -> void:
	ClientManager.update_user_data()

	player_stats.show()
	account_menu.hide()
	credential_form.hide()
	logout_button.show()
	
	update_player_stats_display()

func update_player_stats_display() -> void:
	"""Aggiorna il contenuto delle statistiche del giocatore con i testi localizzati"""
	player_stats.text = ""
	player_stats.text += LocalizationManager.get_text("stats_username") + ": " + ClientManager.user_data.get("username", "N/A") + "\n\n"
	player_stats.text += LocalizationManager.get_text("stats_levels_completed") + ": " + str(ClientManager.user_data.get("mapsCompleted", 0)) + "\n\n"
	player_stats.text += LocalizationManager.get_text("stats_best_score") + ": " + str(ClientManager.user_data.get("bestScore", 0)) + "\n\n"
	var rank_value = ClientManager.user_data.get("rank", "?")
	var rank_str = str(rank_value) if rank_value != null else "?"
	player_stats.text += LocalizationManager.get_text("stats_rank") + ": " + rank_str

func check_auto_login_status() -> void:
	"""Controlla se l'utente è già loggato tramite auto-login"""
	# Aspetta un frame per assicurarsi che GameAPI sia inizializzato
	await get_tree().process_frame
	
	# Se l'utente è già loggato, aggiorna l'interfaccia
	if ClientManager.is_logged_in and not ClientManager.user_data.is_empty():
		GlobalVariables.d_info("User already logged in via auto-login", "AUTHENTICATION")
		# Non mostrare il pannello automaticamente, ma preparalo per quando verrà aperto
		# L'interfaccia verrà aggiornata quando l'utente aprirà il pannello account
