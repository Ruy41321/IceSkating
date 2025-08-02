class_name OptionPanel
extends Control

@onready var aspect_container: AspectRatioContainer = $BackgroundSprite/AspectRatioContainer
@onready var retry_button: Button = $BackgroundSprite/AspectRatioContainer/Menu/RetryButton
@onready var continue_button: Button = $BackgroundSprite/AspectRatioContainer/Menu/ContinueButton
@onready var next_level_button: Button = $BackgroundSprite/AspectRatioContainer/Menu/NextLevelButton
@onready var back_button: Button = $BackgroundSprite/AspectRatioContainer/Menu/BackButton
@onready var no_button: Button = $BackgroundSprite/AspectRatioContainer/Menu/No
@onready var yes_button: Button = $BackgroundSprite/AspectRatioContainer/Menu/Yes
@onready var label: Label = $BackgroundSprite/AspectRatioContainer/StatusLabel

@onready var volume_button: Button = $BackgroundSprite/AspectRatioContainer/VolumeButton
@onready var close_volume_button: TextureButton = $BackgroundSprite/CloseVolumeButton

# Try to get touch overlay if it exists, otherwise fallback to using _input
@onready var touch_overlay: Control = $TouchOverlay if has_node("TouchOverlay") else null

var has_win: bool = false
var is_match_over: bool = false
var current_scene
var player_id: int = -1  # Player ID, used in multiplayer to identify the player

# Container per le opzioni audio (creato dinamicamente)
var options_container: VBoxContainer
var options_ui_initialized: bool = false
var is_showing_volume_options: bool = false

# Confirmation system
var pending_action: String = ""  # "retry" or "back"
var is_showing_confirmation: bool = false
var original_label_text: String = ""  # Store original label text

# Mobile double tap controls
var last_tap_time: float = 0.0
var last_tap_position: Vector2 = Vector2.ZERO
var double_tap_threshold: float = 0.3  # Maximum time between taps to register as double tap
var tap_position_threshold: float = 100.0  # Maximum distance between taps to register as double tap
var tap_count: int = 0

#region DEBUG HELPERS

func _debug_info(message: String, category: String = "MENU") -> void:
	"""Helper function for debug info messages"""
	GlobalVariables.d_info(message, category)

func _debug_verbose(message: String, category: String = "MENU") -> void:
	"""Helper function for verbose debug messages"""
	GlobalVariables.d_verbose(message, category)

func _debug_menu(message: String) -> void:
	"""Quick helper for menu debug messages"""
	GlobalVariables.d_menu(message)

#endregion

func _ready() -> void:
	retry_button.pressed.connect(_on_retry_button_pressed)
	continue_button.pressed.connect(hide_panel)
	next_level_button.pressed.connect(_on_next_level_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)
	volume_button.pressed.connect(_on_volume_button_pressed)
	close_volume_button.pressed.connect(hide_volume_options)
	close_volume_button.hide()
	hide_panel()
	current_scene = get_tree().current_scene
	
	# Setup localization
	setup_localization()
	
	# Connect visibility change to update global state
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect touch overlay if it exists
	if touch_overlay:
		touch_overlay.gui_input.connect(_on_touch_overlay_input)
		_debug_info("Touch overlay connected", "MENU")
	else:
		_debug_info("No touch overlay found, using _input method", "MENU")
	
	# Also connect this control's gui_input as fallback
	gui_input.connect(_on_panel_gui_input)

func _input(event: InputEvent) -> void:
	if get_tree().current_scene is LevelOnline and player_id != ClientManager.my_peer_id:
		return  # Non gestire l'input se non siamo il giocatore corrente
	
	# Handle keyboard input for menu toggle
	if event.is_action_pressed("ui_cancel") and not is_match_over:
		toggle_menu()
		get_viewport().set_input_as_handled()  # Consume the event
	
	# Handle mobile double tap for menu toggle
	elif event is InputEventScreenTouch and event.pressed and not is_match_over:
		_debug_verbose("Touch event received - Match over: %s, Visible: %s" % [is_match_over, visible])
		# Always allow double tap to close/open menu
		# When match is over, only allow closing if menu is visible
		# When match is not over, always allow toggle
		var should_handle_tap = false
		if not is_match_over:
			should_handle_tap = true  # Always allow during gameplay
		elif visible:
			should_handle_tap = true  # Allow closing when match is over and menu is visible
		
		_debug_verbose("Should handle tap: %s" % should_handle_tap)
		
		if should_handle_tap:
			var tap_handled = handle_double_tap(event.position)
			if tap_handled:
				_debug_verbose("Tap was handled, consuming event")
				get_viewport().set_input_as_handled()  # Consume the event if it was a valid double tap

func toggle_menu() -> void:
	"""Toggle the menu visibility"""
	if visible:
		# Se sono aperte le opzioni volume, chiudi solo quelle
		if is_showing_volume_options:
			hide_volume_options()
		else:
			hide_panel()
	else:
		display_option_panel()

func handle_double_tap(tap_position: Vector2) -> bool:
	"""Handle double tap detection for mobile menu opening/closing"""
	var current_timestamp = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	_debug_verbose("Double tap check - Position: %s, Time: %s" % [tap_position, current_timestamp])
	_debug_verbose("Last tap time: %s, Last position: %s, Tap count: %s" % [last_tap_time, last_tap_position, tap_count])
	
	# Check if this could be the second tap of a double tap
	var time_valid = false
	var position_valid = false
	
	if last_tap_time > 0.0:  # Only check time validity if we have a previous tap
		time_valid = current_timestamp - last_tap_time <= double_tap_threshold
		position_valid = tap_position.distance_to(last_tap_position) <= tap_position_threshold
	
	_debug_verbose("Time valid: %s, Position valid: %s" % [time_valid, position_valid])
	
	if time_valid and position_valid and tap_count == 1 and not is_match_over:
		# This is the second tap of a valid double tap
		_debug_info("DOUBLE TAP DETECTED! Toggling menu. Current visible: %s" % visible)
		toggle_menu()
		tap_count = 0
		last_tap_time = current_timestamp
		return true  # Tap was handled as double tap
	else:
		# This is either the first tap or an invalid second tap
		tap_count = 1
		last_tap_position = tap_position
		last_tap_time = current_timestamp
		_debug_verbose("Recorded as first tap or reset sequence")
	
	return false  # Tap was not handled as double tap

func _on_retry_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	# Se il match è finito e il giocatore ha perso, non chiedere conferma
	if is_match_over and not has_win:
		_execute_retry_action()
	else:
		show_confirmation("retry")

func _on_back_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	show_confirmation("back")

func show_confirmation(action: String) -> void:
	"""Show confirmation dialog for destructive actions"""
	pending_action = action
	is_showing_confirmation = true
	
	# Store the original label text before changing it
	original_label_text = label.text
	
	# Hide all buttons except yes/no
	retry_button.hide()
	continue_button.hide()
	next_level_button.hide()
	back_button.hide()
	volume_button.hide()
	
	# Hide options container if visible
	if options_container:
		options_container.hide()
		close_volume_button.hide()

	# Show yes/no buttons
	yes_button.show()
	no_button.show()
	
	# Update label text based on action
	match action:
		"retry":
			label.text = LocalizationManager.get_text("confirm_restart")
		"back":
			label.text = LocalizationManager.get_text("confirm_exit")
		_:
			label.text = "Are you sure?"
	
	_debug_info("Showing confirmation for action: " + action, "MENU")

func _on_yes_button_pressed() -> void:
	"""Execute the pending action"""
	AudioManager.play_ui_sound("click")
	_debug_info("User confirmed action: " + pending_action, "MENU")
	
	match pending_action:
		"retry":
			_execute_retry_action()
		"back":
			_execute_back_action()
	
	# Reset confirmation state
	pending_action = ""
	is_showing_confirmation = false

func _on_no_button_pressed() -> void:
	"""Cancel the pending action and return to previous state"""
	AudioManager.play_ui_sound("click")
	_debug_info("User cancelled action: " + pending_action, "MENU")
	
	# Reset confirmation state
	pending_action = ""
	is_showing_confirmation = false
	
	# Hide yes/no buttons
	yes_button.hide()
	no_button.hide()
	
	# Restore the original label text
	label.text = original_label_text
	
	# Restore previous state
	if is_match_over:
		display_end_game_buttons()
	else:
		display_option_panel_buttons()

func _execute_retry_action() -> void:
	"""Execute the actual retry logic"""
	retry_button.disabled = true
	continue_button.disabled = true
	next_level_button.disabled = true
	if LevelManager.is_ranked_mode:
		if LevelManager.bonus_life_amount > 0:
			LevelManager.bonus_life_amount -= 1  # Decrease bonus life count
	if current_scene is LevelOnline:
		ClientManager.notify_retry()
	elif current_scene is LevelOffline:
		LevelManager.has_retried = true
		LevelManager.wipe_player_list()
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.loading_screen_path)

func _execute_back_action() -> void:
	"""Execute the actual back logic"""
	back_button.disabled = true
	if current_scene is LevelOnline:
		ClientManager.handle_exit()
	elif current_scene is LevelOffline:
		LevelManager.wipe_player_list()
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.start_menu_path)

func _on_next_level_button_pressed() -> void:
	AudioManager.play_ui_sound("click")
	next_level_button.disabled = true
	retry_button.disabled = true
	if current_scene is LevelOnline:
		ClientManager.notify_continue()
	elif current_scene is LevelOffline:
		LevelManager.wipe_player_list()
		get_tree().call_deferred("change_scene_to_file", GlobalVariables.loading_screen_path)

func display_end_game(has_win_local: bool, win_strike: int = -1) -> void:
	if is_match_over:
		_debug_info("End game already displayed, ignoring new call", "MENU")
		return
	is_match_over = true
	continue_button.hide()
	self.has_win = has_win_local
		
	var base_message = ""
	
	if has_win_local:
		if LevelManager.is_playing_offline():
			base_message = LocalizationManager.get_text("option_you_won") + "\n" + LocalizationManager.get_text("option_moves_count", [LevelManager.current_moves_count])
		else:
			if LevelManager.is_ranked_mode:
				base_message = LocalizationManager.get_text("option_you_won") + "!\n" + LocalizationManager.get_text("option_win_strike", [win_strike])
			else:
				base_message = LocalizationManager.get_text("option_you_won") + "!\n" + LocalizationManager.get_text("option_levels_completed", [ClientManager.user_data.get("mapsCompleted", 0)])
		next_level_button.show()
	else:
		AudioManager.play_game_sfx("game_over")
		if LevelManager.is_playing_offline():
			base_message = LocalizationManager.get_text("option_you_lost") + "!"
		else:
			if LevelManager.is_ranked_mode:
				for i in range(LevelManager.starting_bonus_life_amount):
					if i < LevelManager.bonus_life_amount:
						base_message += LocalizationManager.get_text("ranked_bonus_life_available")
					else:
						base_message += LocalizationManager.get_text("ranked_bonus_life_used")
				base_message += "\n"
				base_message += LocalizationManager.get_text("option_you_lost") + "!\n" + LocalizationManager.get_text("option_win_strike", [win_strike])
			else:
				base_message += LocalizationManager.get_text("option_you_lost") + "!\n" + LocalizationManager.get_text("option_levels_completed", [ClientManager.user_data.get("mapsCompleted", 0)])
		next_level_button.hide()
			
	label.text = base_message
	display_end_game_buttons()
	show_panel()

func get_bonus_life_message() -> String:
	# Fallback message
	return LocalizationManager.get_text("ranked_mode_active")

func display_end_game_buttons() -> void:
	"""Display buttons for end game state"""
	# Hide yes/no buttons
	yes_button.hide()
	no_button.hide()
	
	# Hide volume button during end game
	volume_button.hide()
	
	# Hide options container if visible
	if options_container:
		options_container.hide()
		close_volume_button.hide()

	# Show game end buttons
	back_button.show()
	retry_button.show()
	label.show()

	next_level_button.visible = 1 if has_win else 0
	
	if ClientManager.is_host or current_scene is LevelOffline:
		next_level_button.disabled = false
		retry_button.disabled = false
	else:
		next_level_button.disabled = true
		retry_button.disabled = true
	
	# Reset volume options state
	is_showing_volume_options = false

#region VISIBILITY CONTROL

func show_panel() -> void:
	"""Show the option panel and update global state"""
	show()
	GlobalVariables.is_option_panel_open = true

func hide_panel() -> void:
	"""Hide the option panel and update global state"""
	AudioManager.play_ui_sound("click")
	hide()
	GlobalVariables.is_option_panel_open = false
	GlobalVariables.last_option_panel_close_time = Time.get_ticks_msec() / 1000.0

func _on_visibility_changed() -> void:
	"""Update global state when visibility changes"""
	GlobalVariables.is_option_panel_open = visible

#endregion

func display_option_panel() -> void:
	var base_message = ""

	if LevelManager.is_ranked_mode:
		for i in range(LevelManager.starting_bonus_life_amount):
			if i < LevelManager.bonus_life_amount:
				base_message += LocalizationManager.get_text("ranked_bonus_life_available")
			else:
				base_message += LocalizationManager.get_text("ranked_bonus_life_used")
		base_message += "\n"
	base_message += LocalizationManager.get_text("option_current_moves", [LevelManager.current_moves_count])
	label.text = base_message
	display_option_panel_buttons()
	show_panel()

func display_option_panel_buttons() -> void:
	"""Display buttons for option panel state"""
	# Hide yes/no buttons
	yes_button.hide()
	no_button.hide()
	
	# Hide options container if visible
	if options_container:
		options_container.hide()
		close_volume_button.hide()

	# Show option panel buttons
	retry_button.show()
	continue_button.show()
	back_button.show()
	volume_button.show()
	label.show()
	next_level_button.hide()
	retry_button.disabled = false if ClientManager.is_host or current_scene is LevelOffline else true
	
	# Reset volume options state
	is_showing_volume_options = false

func _on_volume_button_pressed() -> void:
	"""Gestisce la pressione del pulsante volume"""
	AudioManager.play_ui_sound("click")
	show_volume_options()

func show_volume_options() -> void:
	"""Mostra il pannello delle opzioni audio"""
	# Nascondi tutti gli altri elementi del menu
	hide_all_menu_elements()
	
	# Setup dell'interfaccia options
	_setup_options_ui()
	
	# Mostra il container delle opzioni
	if options_container:
		options_container.show()
		close_volume_button.show()
	
	# Aggiorna lo stato
	is_showing_volume_options = true
	show_panel()

func hide_volume_options() -> void:
	"""Nascondi il pannello delle opzioni audio e torna al menu principale"""
	if options_container:
		options_container.hide()
		close_volume_button.hide()
	
	is_showing_volume_options = false
	
	# Ripristina il menu normale in base allo stato del gioco
	if is_match_over:
		display_end_game_buttons()
	else:
		display_option_panel_buttons()

func _setup_options_ui() -> void:
	"""Configura l'interfaccia delle opzioni con slider interattivi"""
	# Se l'UI è già stata inizializzata, aggiorna solo i valori
	if options_ui_initialized:
		AudioOptionsManager.update_slider_values()
		return
	
	# Assicurati che AudioOptionsManager sia configurato
	AudioOptionsManager.load_saved_volume_settings()
	AudioOptionsManager.setup_volume_controls()
	
	# Assicurati che il container esista
	if not options_container:
		options_container = VBoxContainer.new()
		options_container.name = "OptionsContainer"
		options_container.set_alignment(BoxContainer.ALIGNMENT_CENTER)
		options_container.set_h_size_flags(Control.SIZE_SHRINK_CENTER)
		options_container.set_v_size_flags(Control.SIZE_SHRINK_BEGIN)

	# Se il container non è già stato aggiunto, lo aggiungiamo
	if not options_container.get_parent():
		# Trova il parent corretto (AspectRatioContainer)
		aspect_container.add_child(options_container)
	
	# Crea l'interfaccia delle opzioni utilizzando il manager
	await AudioOptionsManager.create_options_ui(options_container)
	
	# Marca come inizializzato
	options_ui_initialized = true

func hide_all_menu_elements() -> void:
	"""Nascondi tutti gli elementi del menu"""
	retry_button.hide()
	continue_button.hide()
	next_level_button.hide()
	back_button.hide()
	yes_button.hide()
	no_button.hide()
	volume_button.hide()
	label.hide()

#endregion

#region VISIBILITY CONTROL

func _on_panel_gui_input(event: InputEvent) -> void:
	"""Handle GUI input directly on the panel"""
	if not visible:
		return
		
	if event is InputEventScreenTouch and event.pressed:
		_debug_verbose("Panel GUI input event received", "MENU")
		var should_handle_tap = false
		if not is_match_over:
			should_handle_tap = true  # Always allow during gameplay
		elif visible:
			should_handle_tap = true  # Allow closing when match is over and menu is visible
		
		if should_handle_tap:
			var tap_handled = handle_double_tap(event.position)
			if tap_handled:
				_debug_verbose("Panel GUI tap was handled", "MENU")

func _on_touch_overlay_input(event: InputEvent) -> void:
	"""Handle touch input from the overlay when menu is visible"""
	if not visible:
		return
		
	if event is InputEventScreenTouch and event.pressed:
		_debug_verbose("Touch overlay event received", "MENU")
		var should_handle_tap = false
		if not is_match_over:
			should_handle_tap = true  # Always allow during gameplay
		elif visible:
			should_handle_tap = true  # Allow closing when match is over and menu is visible
		
		if should_handle_tap:
			var tap_handled = handle_double_tap(event.position)
			if tap_handled:
				_debug_verbose("Overlay tap was handled", "MENU")

# Localization functions
func setup_localization() -> void:
	"""Setup localization system"""
	if LocalizationManager:
		LocalizationManager.language_changed.connect(_on_language_changed)
		update_all_texts()

func update_all_texts() -> void:
	"""Update all text elements with localized content"""
	if not LocalizationManager:
		return
	
	# Update button texts
	if retry_button:
		retry_button.text = LocalizationManager.get_text("menu_retry")
	if continue_button:
		continue_button.text = LocalizationManager.get_text("menu_continue")
	if next_level_button:
		next_level_button.text = LocalizationManager.get_text("menu_next_level")
	if back_button:
		back_button.text = LocalizationManager.get_text("menu_back")
	if yes_button:
		yes_button.text = LocalizationManager.get_text("menu_yes")
	if no_button:
		no_button.text = LocalizationManager.get_text("menu_no")
	if volume_button:
		volume_button.text = LocalizationManager.get_text("menu_volume")
	
	# Update label text based on current state
	if is_showing_confirmation:
		match pending_action:
			"retry":
				label.text = LocalizationManager.get_text("confirm_restart")
			"back":
				label.text = LocalizationManager.get_text("confirm_exit")
	elif is_match_over:
		# Update end game messages
		if has_win:
			if LevelManager.is_playing_offline():
				label.text = LocalizationManager.get_text("option_you_won") + "\n" + LocalizationManager.get_text("option_moves_count", [LevelManager.current_moves_count])
			else:
				# Per il multiplayer, dovremmo avere accesso al win_strike, per ora usiamo un placeholder
				label.text = LocalizationManager.get_text("option_you_won") + "!"
		else:
			label.text = LocalizationManager.get_text("option_you_lost") + "!"
	elif visible:
		# Update current moves message
		label.text = LocalizationManager.get_text("option_current_moves", [LevelManager.current_moves_count])

func _on_language_changed() -> void:
	"""Handle language change event"""
	# Reset options UI per permettere ricreazione con nuovi testi
	options_ui_initialized = false
	
	update_all_texts()
	
	# Se le opzioni volume sono attualmente visibili, ricreale con i nuovi testi
	if is_showing_volume_options and options_container:
		await _setup_options_ui()
