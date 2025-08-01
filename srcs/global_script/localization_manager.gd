# LocalizationManager.gd - Sistema di gestione multilingue
extends Node

#region CONFIGURATION

var current_language: String = "it"  # Lingua predefinita: italiano
var available_languages: Array = ["it", "en"]  # Lingue disponibili

# Dizionario principale delle traduzioni
var translations: Dictionary = {}

#endregion

#region SIGNALS

signal language_changed(new_language: String)

#endregion

#region INITIALIZATION

func _ready() -> void:
	"""Inizializza il sistema di localizzazione"""
	load_translations()
	load_saved_language()
	GlobalVariables.d_info("Localization Manager initialized with language: " + current_language, "LOCALIZATION")

func load_translations() -> void:
	"""Carica tutte le traduzioni disponibili"""
	translations = {
		"it": {
			# Menu principale
			"menu_play": "Gioca",
			"menu_credits": "Crediti",
			"menu_info": "Info",
			"menu_options": "Opzioni",
			"menu_quit": "Esci",
			"menu_back": "Indietro",
			"menu_continue": "Continua",
			"menu_retry": "Riprova",
			"menu_next_level": "Prossimo Livello",
			"menu_yes": "Sì",
			"menu_no": "No",
			"menu_volume": "Volume",

			# Modalità di gioco
			"game_career": "Carriera",
			"game_ranked": "Classificata",
			"game_training": "Allenamento",
			"game_leaderboard": "Classifica",
			"game_single_player": "Giocatore Singolo",
			"game_multiplayer": "Multigiocatore",
			"game_create_room": "Crea Stanza Privata",
			"game_quick_join": "Accesso Rapido",
			
			# Modalità classificata
			"game_ranked_leaderboard": "Classificata",
			"game_levels_leaderboard": "Carriera",

			# Difficoltà
			"difficulty_easy": "Facile",
			"difficulty_medium": "Medio",
			"difficulty_hard": "Difficile",
			
			# Account e login
			"account_login": "Accedi",
			"account_register": "Registrati",
			"account_logout": "Disconnetti",
			"account_username": "Nome Utente",
			"account_password": "Password",
			"account_submit": "Invia",
			"account_back": "Indietro",
			"account_login_required": "Devi effettuare l'accesso per giocare online",
			"account_login_successful": "Accesso riuscito!",
			"account_login_failed": "Accesso fallito",
			"account_connecting": "Connessione...",
			"account_empty_fields": "Nome utente e password non possono essere vuoti.",
			"account_auto_login": "Accesso automatico in corso...",
			"account_session_expired": "Sessione scaduta, accedi nuovamente",
			"account_welcome_back": "Bentornato, %s!",
			
			# Codici errore API
			"error_invalid_credentials": "Credenziali non valide",
			"error_username_exists": "Nome utente già esistente",
			"error_invalid_token": "Token di accesso non valido",
			"error_server_error": "Errore del server",
			"error_network_error": "Errore di connessione",
			"error_invalid_request": "Richiesta non valida",
			"error_user_not_found": "Utente non trovato",
			"error_unknown": "Errore sconosciuto",
			
			# Statistiche giocatore
			"stats_username": "Nome Utente",
			"stats_levels_completed": "Livelli Completati",
			"stats_best_score": "Miglior Punteggio",
			"stats_rank": "Classificazione",
			
			# Crediti
			"credits_title": "CREDITI",
			"credits_executive_producer": "Produttore Esecutivo:",
			"credits_game_mechanics": "Meccaniche di Gioco:",
			"credits_artist": "Artista:",
			"credits_thanks": "Grazie per aver giocato!",
			
			# Info di gioco
			"info_title": "COME GIOCARE",
			"info_objective": "Obiettivo:",
			"info_objective_text": "Trova l'uscita dalla grotta ghiacciata, attento ai buchi ;)",
			"info_controls": "Controlli:",
			"info_pc_movement": "PC: Usa le frecce direzionali della tastiera",
			"info_pc_menu": "PC: Premi Esc per aprire il menu",
			"info_mobile_movement": "Mobile: Fai swipe nella direzione desiderata",
			"info_mobile_menu": "Mobile: Doppio click per aprire il menu",
			"info_good_luck": "Buona fortuna!",
			
			# Opzioni audio
			"options_title": "OPZIONI AUDIO",
			"options_master_volume": "Volume Principale:",
			"options_sfx_volume": "Volume Effetti:",
			"options_ui_volume": "Volume Interfaccia:",
			"options_music_volume": "Volume Musica:",
			"options_instructions": "Controlla i volumi dal menu principale",
			
			# Classifica
			"leaderboard_title": "CLASSIFICA",
			"leaderboard_levels_title": "CLASSIFICA LIVELLI",
			"leaderboard_loading": "Caricamento...",
			"leaderboard_error": "Errore nel caricamento della classifica",
			"leaderboard_empty": "Nessun giocatore in classifica",
			"leaderboard_position": "Pos.",
			"leaderboard_name": "Nome",
			"leaderboard_best_score": "Punteggio",
			"leaderboard_levels_completed": "Livelli",
			
			# Messaggi di gioco
			"game_moves": "Mosse: %d",
			"game_server_not_available": "Server non disponibile",
			"game_other_player_disconnected": "L'altro giocatore si è disconnesso.",
			"game_map_generation_error": "Errore critico nella generazione della mappa\\nRiprova\\nSe il problema persiste, contatta il supporto.",
			"game_connecting": "Connessione...",
			"game_room_id": "Il tuo room_id è %s",
			"game_room_placeholder": "Inserisci Room Id",
			
			# Messaggi di connessione
			"connection_room_created": "Stanza Creata: %s",
			"connection_waiting_opponent": "In attesa dell'avversario...",
			"connection_room_full": "La Stanza \"%s\" è già piena",
			"connection_already_in_room": "Sei già nella Stanza: %s",
			"connection_room_not_found": "Stanza \"%s\" non trovata",
			"connection_account_in_use": "Un altro dispositivo sta già\nutilizzando questo account.",
			"connection_map_loading_failed": "Errore imprevisto nel caricamento della mappa\nRiprova più tardi.",
			"connection_timeout": "Timeout di connessione",
			"connection_error": "Errore: %s",
			
			# Conferme
			"confirm_exit": "Sei sicuro di voler uscire?",
			"confirm_restart": "Sei sicuro di voler ricominciare?",
			
			# Messaggi option panel
			"option_you_won": "Hai Vinto",
			"option_you_lost": "Hai Perso",
			"option_moves_count": "usando %d mosse!",
			"option_win_strike": "Punteggio: %d",
			"option_levels_completed": "Livello: %d",
			"option_current_moves": "Hai fatto %d mosse",
			
			# Messaggi modalità classificata
			"ranked_bonus_life_available": "💖",
			"ranked_bonus_life_used": "🖤",
			"ranked_mode_active": "🏆 Modalità Ranked Attiva",
			
			# Lingua
			"language_italian": "Italiano",
			"language_english": "English",
			"language_title": "Lingua"
		},
		
		"en": {
			# Main menu
			"menu_play": "Play",
			"menu_credits": "Credits",
			"menu_info": "Info",
			"menu_options": "Options",
			"menu_quit": "Quit",
			"menu_back": "Back",
			"menu_continue": "Continue",
			"menu_retry": "Retry",
			"menu_next_level": "Next Level",
			"menu_yes": "Yes",
			"menu_no": "No",
			"menu_volume": "Volume",
			
			# Game modes
			"game_career": "Career",
			"game_ranked": "Ranked",
			"game_training": "Training",
			"game_leaderboard": "Leaderboard",
			"game_single_player": "Single-Player",
			"game_multiplayer": "Multi-Player",
			"game_create_room": "Create Private Room",
			"game_quick_join": "Quick Join",
			
			# Ranked mode
			"game_ranked_leaderboard": "Ranked",
			"game_levels_leaderboard": "Career",

			# Difficulty
			"difficulty_easy": "Easy",
			"difficulty_medium": "Medium",
			"difficulty_hard": "Hard",
			
			# Account and login
			"account_login": "Login",
			"account_register": "Register",
			"account_logout": "Logout",
			"account_username": "Username",
			"account_password": "Password",
			"account_submit": "Submit",
			"account_back": "Back",
			"account_login_required": "You must log in to play online",
			"account_login_successful": "Login successful!",
			"account_login_failed": "Login failed",
			"account_connecting": "Connecting...",
			"account_empty_fields": "Username and password cannot be empty.",
			"account_auto_login": "Auto login in progress...",
			"account_session_expired": "Session expired, please log in again",
			"account_welcome_back": "Welcome back, %s!",
			
			# API Error codes
			"error_invalid_credentials": "Invalid credentials",
			"error_username_exists": "Username already exists",
			"error_invalid_token": "Invalid access token",
			"error_server_error": "Server error",
			"error_network_error": "Connection error",
			"error_invalid_request": "Invalid request",
			"error_user_not_found": "User not found",
			"error_unknown": "Unknown error",
			
			# Player stats
			"stats_username": "Username",
			"stats_levels_completed": "Level Completed",
			"stats_best_score": "Best Score",
			"stats_rank": "Rank",
			
			# Credits
			"credits_title": "CREDITS",
			"credits_executive_producer": "Executive Producer:",
			"credits_game_mechanics": "Game Mechanics:",
			"credits_artist": "Artist:",
			"credits_thanks": "Thanks for playing!",
			
			# Game info
			"info_title": "HOW TO PLAY",
			"info_objective": "Objective:",
			"info_objective_text": "Find the exit from the frozen cave, watch out for holes ;)",
			"info_controls": "Controls:",
			"info_pc_movement": "PC: Use keyboard arrow keys",
			"info_pc_menu": "PC: Press Esc to open menu",
			"info_mobile_movement": "Mobile: Swipe in the desired direction",
			"info_mobile_menu": "Mobile: Double tap to open menu",
			"info_good_luck": "Good luck!",
			
			# Audio options
			"options_title": "AUDIO OPTIONS",
			"options_master_volume": "Master Volume:",
			"options_sfx_volume": "Sound Effects:",
			"options_ui_volume": "Interface Volume:",
			"options_music_volume": "Music Volume:",
			"options_instructions": "Adjust volumes from the main menu",
			
			# Leaderboard
			"leaderboard_title": "LEADERBOARD",
			"leaderboard_levels_title": "LEVELS LEADERBOARD",
			"leaderboard_loading": "Loading...",
			"leaderboard_error": "Error loading leaderboard",
			"leaderboard_empty": "No players in leaderboard",
			"leaderboard_position": "Pos.",
			"leaderboard_name": "Name",
			"leaderboard_best_score": "Score",
			"leaderboard_levels_completed": "Levels",
			
			# Game messages
			"game_moves": "Moves: %d",
			"game_server_not_available": "Server not available",
			"game_other_player_disconnected": "The other player disconnected.",
			"game_map_generation_error": "Critical error generating the map\\nPlease try again\\nIf the problem persists, contact the support.",
			"game_connecting": "Connecting...",
			"game_room_id": "Your room_id is %s",
			"game_room_placeholder": "Insert Room Id",
			
			# Connection messages
			"connection_room_created": "Room Created: %s",
			"connection_waiting_opponent": "Waiting for opponent...",
			"connection_room_full": "The Room \"%s\" is already Full",
			"connection_already_in_room": "You are already in the Room: %s",
			"connection_room_not_found": "Room \"%s\" not found",
			"connection_account_in_use": "Another device is already\nplaying with this account.",
			"connection_map_loading_failed": "Unexpected error while loading the map\nplease try again later.",
			"connection_timeout": "Connection timeout",
			"connection_error": "Error: %s",
			
			# Confirmations
			"confirm_exit": "Are you sure you want to exit?",
			"confirm_restart": "Are you sure you want to restart?",
			
			# Option panel messages
			"option_you_won": "You Won",
			"option_you_lost": "You Lost",
			"option_moves_count": "using %d moves!",
			"option_win_strike": "Score: %d",
			"option_levels_completed": "Level: %d",
			"option_current_moves": "You did %d moves",
			
			# Ranked mode messages
			"ranked_bonus_life_available": "💖",
			"ranked_bonus_life_used": "🖤",
			"ranked_mode_active": "🏆 Ranked Mode Active",
			
			# Language
			"language_italian": "Italiano",
			"language_english": "English",
			"language_title": "Language"
		}
	}

#endregion

#region PUBLIC METHODS

func get_text(key: String, args: Array = []) -> String:
	"""
	Ottiene il testo tradotto per la chiave specificata
	
	Args:
		key: Chiave della traduzione
		args: Argomenti opzionali per la formattazione
		
	Returns:
		Testo tradotto o la chiave se non trovata
	"""
	if not translations.has(current_language):
		GlobalVariables.d_warning("Language not found: " + current_language, "LOCALIZATION")
		return key
	
	var language_dict = translations[current_language]
	if not language_dict.has(key):
		GlobalVariables.d_warning("Translation key not found: " + key, "LOCALIZATION")
		return key
	
	var text = language_dict[key]
	
	# Applica formattazione se ci sono argomenti
	if args.size() > 0:
		text = text % args
	
	return text

func set_language(language_code: String) -> void:
	"""
	Cambia la lingua corrente
	
	Args:
		language_code: Codice della lingua (es. "it", "en")
	"""
	if language_code in available_languages:
		current_language = language_code
		save_language_preference()
		language_changed.emit(current_language)
		GlobalVariables.d_info("Language changed to: " + current_language, "LOCALIZATION")
	else:
		GlobalVariables.d_error("Unsupported language: " + language_code, "LOCALIZATION")

func get_current_language() -> String:
	"""Ottiene la lingua corrente"""
	return current_language

func get_available_languages() -> Array:
	"""Ottiene la lista delle lingue disponibili"""
	return available_languages.duplicate()

func get_language_display_name(language_code: String) -> String:
	"""
	Ottiene il nome della lingua da mostrare nell'interfaccia
	
	Args:
		language_code: Codice della lingua
		
	Returns:
		Nome della lingua localizzato
	"""
	match language_code:
		"it":
			return get_text("language_italian")
		"en":
			return get_text("language_english")
		_:
			return language_code.to_upper()

func get_error_message(error_code: String) -> String:
	"""
	Ottiene il messaggio di errore localizzato per un codice di errore
	
	Args:
		error_code: Codice dell'errore (es. "INVALID_CREDENTIALS", "USERNAME_EXISTS")
		
	Returns:
		Messaggio di errore localizzato
	"""
	# Converte il codice errore in chiave di traduzione
	var error_key = "error_" + error_code.to_lower()
	
	# Tenta di ottenere il messaggio localizzato
	var localized_message = get_text(error_key)
	
	# Se non trova la traduzione, ritorna un messaggio generico
	if localized_message == error_key:
		return get_text("error_unknown")
	
	return localized_message

#endregion

#region PRIVATE METHODS

func load_saved_language() -> void:
	"""Carica la lingua salvata dalle preferenze"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		var saved_language = config.get_value("localization", "language", "it")
		if saved_language in available_languages:
			current_language = saved_language
		else:
			GlobalVariables.d_warning("Invalid saved language: " + str(saved_language), "LOCALIZATION")

func save_language_preference() -> void:
	"""Salva la lingua corrente nelle preferenze"""
	var config = ConfigFile.new()
	config.load("user://settings.cfg")  # Carica eventuali impostazioni esistenti
	config.set_value("localization", "language", current_language)
	config.save("user://settings.cfg")
	GlobalVariables.d_info("Language preference saved: " + current_language, "LOCALIZATION")

#endregion
