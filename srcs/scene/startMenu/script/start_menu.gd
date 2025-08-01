extends Control
@onready var server_button: Button = $Server

@onready var single_player_button: Button = $CenterContainer/MultiplayerSelection/SinglePlayer
@onready var multi_player_button: Button = $CenterContainer/MultiplayerSelection/Multiplayer
@onready var new_room_button : Button = $CenterContainer/MultiplayerSelection/NewPrivateRoom
@onready var join_button : Button = $CenterContainer/MultiplayerSelection/QuickJoin
@onready var room_id_label : LineEdit = $CenterContainer/MultiplayerSelection/RoomId
@onready var connection_status_label : Label = $CenterContainer/ConnectionStatusLabel

@onready var main_menu: VBoxContainer = $CenterContainer/MainMenu
@onready var play_menu: VBoxContainer = $CenterContainer/PlayMenu
@onready var multiplayer_selection: VBoxContainer = $CenterContainer/MultiplayerSelection

@onready var training_button: Button = $CenterContainer/PlayMenu/TrainingButton
@onready var ranked_button: Button = $CenterContainer/PlayMenu/RankedButton

@onready var difficulty_selection: VBoxContainer = $CenterContainer/DifficultySelection
@onready var easy_selection: Button = $CenterContainer/DifficultySelection/Easy
@onready var medium_selection: Button = $CenterContainer/DifficultySelection/Medium
@onready var hard_selection: Button = $CenterContainer/DifficultySelection/Hard

@onready var account_button: TextureButton = $TopRightContainer/AccountButton
@onready var account_panel: AccountPanel = $CenterContainer/AccountPanel
@onready var basic_panel: Control = $CenterContainer/BasicPanel
@onready var career_button: Button = $CenterContainer/PlayMenu/CareerButton
@onready var credits_button: Button = $CenterContainer/MainMenu/Credits
@onready var info_button: Button = $CenterContainer/MainMenu/Info
@onready var options_button: Button = $CenterContainer/MainMenu/Options
@onready var leaderboard_button: Button = $CenterContainer/MainMenu/LeaderboardButton

@onready var leaderboard_menu: VBoxContainer = $CenterContainer/LeaderboardMenu
@onready var ranked_leaderboard_button: Button = $CenterContainer/LeaderboardMenu/RankedLeaderboardButton
@onready var levels_leaderboard_button: Button = $CenterContainer/LeaderboardMenu/LevelsLeaderboardButton

@onready var play_button: Button = $CenterContainer/MainMenu/Play
@onready var quit_button: Button = $CenterContainer/MainMenu/Quit
@onready var back_buttons: Array[Button] = [
	$CenterContainer/PlayMenu/Back,
	$CenterContainer/DifficultySelection/Back,
	$CenterContainer/MultiplayerSelection/Back,
	$CenterContainer/LeaderboardMenu/Back
]

@onready var language_panel: Control = $CenterContainer/LanguagePanel
@onready var language_button: Button = $LanguageButton


## Function to easily manage menu visibility  
##
## panel_id: int
## 1 -> Main Menu |
## 2 -> Play Menu |
## 3 -> Multiplayer Selection |ì
## 4 -> Difficulty Selection |
## 5 -> Leaderboard Menu |
func set_panel_visibility(panel_id: int = 0):
	main_menu.hide()
	play_menu.hide()
	difficulty_selection.hide()
	multiplayer_selection.hide()
	leaderboard_menu.hide()
	connection_status_label.hide()
	match panel_id:
		1: main_menu.show()
		2: play_menu.show()
		3: multiplayer_selection.show()
		4: difficulty_selection.show()
		5: leaderboard_menu.show()
		_:
			return

func _ready() -> void:
	# Start background music for menu
	AudioManager.play_background_music("menu")
	
	if LevelManager.use_local_server:
		server_button.show()
	else:
		server_button.hide()

	setup_signals()
	setup_localization()

	set_panel_visibility(1)

	if GlobalVariables.map_gen_error:
		connection_status_label.text = LocalizationManager.get_text("game_map_generation_error")
		connection_status_label.show()
		GlobalVariables.map_gen_error = false

	if GlobalVariables.exit_on_peer_disconnect:
		connection_status_label.text = LocalizationManager.get_text("game_other_player_disconnected")
		connection_status_label.show()
		GlobalVariables.exit_on_peer_disconnect = false
		
	account_panel.hide()
	language_panel.hide()
	ClientManager.connection_status_label = connection_status_label
	ClientManager.start_menu_instance = self

func setup_localization() -> void:
	"""Configura il sistema di localizzazione"""
	# Connetti al segnale di cambio lingua
	LocalizationManager.language_changed.connect(_on_language_changed)
	
	# Aggiorna i testi iniziali
	update_all_texts()

func _on_language_changed(_new_language: String) -> void:
	"""Chiamata quando cambia la lingua"""
	update_all_texts()

func update_all_texts() -> void:
	"""Aggiorna tutti i testi dell'interfaccia"""
	# Menu principale
	play_button.text = LocalizationManager.get_text("menu_play")
	credits_button.text = LocalizationManager.get_text("menu_credits")
	info_button.text = LocalizationManager.get_text("menu_info")
	options_button.text = LocalizationManager.get_text("menu_options")
	quit_button.text = LocalizationManager.get_text("menu_quit")
	
	# Menu di gioco
	career_button.text = LocalizationManager.get_text("game_career")
	ranked_button.text = LocalizationManager.get_text("game_ranked")
	training_button.text = LocalizationManager.get_text("game_training")
	leaderboard_button.text = LocalizationManager.get_text("game_leaderboard")
	
	# Selezione multiplayer
	single_player_button.text = LocalizationManager.get_text("game_single_player")
	multi_player_button.text = LocalizationManager.get_text("game_multiplayer")
	new_room_button.text = LocalizationManager.get_text("game_create_room")
	join_button.text = LocalizationManager.get_text("game_quick_join")
	room_id_label.placeholder_text = LocalizationManager.get_text("game_room_placeholder")
	
	# Selezione difficoltà
	easy_selection.text = LocalizationManager.get_text("difficulty_easy")
	medium_selection.text = LocalizationManager.get_text("difficulty_medium")
	hard_selection.text = LocalizationManager.get_text("difficulty_hard")
	
	# Pulsanti "Indietro"
	for back_button in back_buttons:
		if back_button:
			back_button.text = LocalizationManager.get_text("menu_back")
	
	# Pulsante lingua
	language_button.text = LocalizationManager.get_language_display_name(LocalizationManager.get_current_language())

func setup_signals() -> void:
	# Connect button signals with audio feedback
	room_id_label.text_changed.connect(_on_ip_address_text_changed)
	
	# Main menu buttons
	play_button.pressed.connect(_on_play_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	info_button.pressed.connect(_on_info_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Game mode buttons  
	career_button.pressed.connect(_on_career_button_pressed)
	training_button.pressed.connect(_on_training_button_pressed)
	ranked_button.pressed.connect(_on_ranked_button_pressed)
	leaderboard_button.pressed.connect(_on_leaderboard_button_pressed)
	
	# Multiplayer buttons
	single_player_button.pressed.connect(_on_single_player_button_pressed)
	multi_player_button.pressed.connect(_on_multi_player_button_pressed)
	new_room_button.pressed.connect(_on_new_room_pressed)
	join_button.pressed.connect(_on_join_pressed)
	
	# Difficulty buttons 
	easy_selection.pressed.connect(_on_training_button_pressed.bind("easy"))
	medium_selection.pressed.connect(_on_training_button_pressed.bind("medium"))
	hard_selection.pressed.connect(_on_training_button_pressed.bind("hard"))
	
	# Leaderboard buttons
	ranked_leaderboard_button.pressed.connect(basic_panel.show_leaderboard.bind("ranked"))
	levels_leaderboard_button.pressed.connect(basic_panel.show_leaderboard.bind("levels"))
	
	# Back buttons  
	for back_button in back_buttons:
		if back_button:
			back_button.pressed.connect(_on_back_pressed)
	
	# Other buttons
	account_button.pressed.connect(_on_account_button_pressed)
	language_button.pressed.connect(_on_language_button_pressed)
	credits_button.pressed.connect(basic_panel.show_credits)
	info_button.pressed.connect(basic_panel.show_info)

func _on_language_button_pressed() -> void:
	"""Mostra il pannello di selezione lingua"""
	AudioManager.play_ui_sound("click")
	language_panel.show()

func _on_play_pressed() -> void:
	AudioManager.play_ui_sound("click")
	set_panel_visibility(2)

func _on_quit_pressed() -> void:
	AudioManager.play_ui_sound("click")
	ClientManager.quit_connection()
	get_tree().quit()

func _on_training_button_pressed(difficulty_type: String = "") -> void:
	AudioManager.play_ui_sound("click")
	if not difficulty_type.is_empty():
		LevelManager.is_ranked_mode = false  # Reset ranked mode for training
		LevelManager.difficulty_type = difficulty_type
		LevelManager.new_map = true 
		get_tree().change_scene_to_file(GlobalVariables.loading_screen_path)
		return
	set_panel_visibility(4)

func _on_career_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	if not ClientManager.is_logged_in and not LevelManager.use_local_server:
		account_panel.trying_to_play_without_login.emit()
	else:
		set_panel_visibility(3)
		single_player_button.show()
		multi_player_button.show()
		new_room_button.hide()
		join_button.hide()
		room_id_label.hide()
		connection_status_label.hide()

func _on_ranked_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	if not ClientManager.is_logged_in and not LevelManager.use_local_server:
		account_panel.trying_to_play_without_login.emit()
	else:
		# In ranked mode, skip multiplayer selection and go directly to single player
		LevelManager.is_ranked_mode = true
		ClientManager.become_client("ranked")
		set_panel_visibility(0)
		connection_status_label.text = LocalizationManager.get_text("game_connecting")
		connection_status_label.visible = 1

func _on_single_player_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	LevelManager.is_ranked_mode = false  # Reset ranked mode for normal play
	ClientManager.become_client("single_player")
	single_player_button.visible = 0
	multi_player_button.visible = 0

func _on_multi_player_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	if not ClientManager.is_logged_in and not LevelManager.use_local_server:
		account_panel.show()
		account_panel.trying_to_play_without_login.emit()
	else:
		LevelManager.is_ranked_mode = false  # Reset ranked mode for normal play
		set_panel_visibility(3)
		single_player_button.hide()
		multi_player_button.hide()
		new_room_button.show()
		join_button.show()
		room_id_label.show()
		connection_status_label.hide()

func _on_new_room_pressed() -> void:
	AudioManager.play_ui_sound("click")
	ClientManager.become_client("new_private")
	new_room_button.visible = 0
	join_button.visible = 0
	room_id_label.visible = 0
	
func _on_join_pressed() -> void:
	AudioManager.play_ui_sound("click")
	if room_id_label.text == "":
		ClientManager.become_client("quick_join")
	else:
		ClientManager.become_client(room_id_label.text)
	connection_status_label.text = LocalizationManager.get_text("game_connecting")
	connection_status_label.visible = 1
	new_room_button.visible = 0
	join_button.visible = 0
	room_id_label.visible = 0
	
func _on_back_pressed() -> void:
	AudioManager.play_ui_sound("click")
	if ClientManager.is_connection_open():
		ClientManager.quit_connection()
	set_panel_visibility(1)
	
func _on_ip_address_text_changed(new_text: String) -> void:
	if new_text == "":
		join_button.text = "Quick Join"
		new_room_button.disabled = false
	else:
		join_button.text = "Join"
		new_room_button.disabled = true

func _on_server_pressed() -> void:
	ServerManager.become_host()
	hide()

func authentication_successfull(player_data: Dictionary) -> void:
	GlobalVariables.d_info("Authentication successful: " + str(player_data.get("username", "")), "AUTHENTICATION")

func authentication_failed(status: String) -> void:
	GlobalVariables.d_warning("Authentication failed: " + str(status), "AUTHENTICATION")
	set_panel_visibility(1)
	ClientManager.is_logged_in = false
	account_panel.trying_to_play_without_login.emit()

func _on_leaderboard_button_pressed() -> void:
	"""Mostra il menu di selezione delle leaderboard"""
	AudioManager.play_ui_sound("click")
	set_panel_visibility(5)

func _on_credits_button_pressed() -> void:
	"""Mostra i crediti del gioco"""
	AudioManager.play_ui_sound("click")
	basic_panel.show_credits()

func _on_info_button_pressed() -> void:
	"""Mostra le informazioni del gioco"""
	AudioManager.play_ui_sound("click")
	basic_panel.show_info()

func _on_options_button_pressed() -> void:
	"""Mostra le opzioni del gioco"""
	AudioManager.play_ui_sound("click")
	basic_panel.show_option()

func _on_account_button_pressed() -> void:
	"""Mostra il pannello account"""
	AudioManager.play_ui_sound("click")
	account_panel._on_account_button_pressed()
