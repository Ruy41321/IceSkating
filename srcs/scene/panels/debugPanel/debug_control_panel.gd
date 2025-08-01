# Debug Control Panel
# Add this to a scene as a CanvasLayer for runtime debug control

extends CanvasLayer

@onready var debug_level_option: OptionButton = $VBoxContainer/DebugLevelContainer/DebugLevelOption
@onready var category_list: VBoxContainer = $VBoxContainer/ScrollContainer/CategoryList
@onready var status_label: Label = $VBoxContainer/StatusLabel

var debug_manager: Node

func _ready() -> void:
	# Get debug manager
	debug_manager = get_node("/root/DebugManager")
	if not debug_manager:
		push_error("DebugManager not found!")
		return
	
	setup_debug_level_options()
	setup_category_checkboxes()
	update_status()

func setup_debug_level_options() -> void:
	"""Setup debug level dropdown"""
	debug_level_option.add_item("NONE", 0)
	debug_level_option.add_item("ERROR", 1)
	debug_level_option.add_item("WARNING", 2)
	debug_level_option.add_item("INFO", 3)
	debug_level_option.add_item("DEBUG", 4)
	debug_level_option.add_item("VERBOSE", 5)
	
	# Set current selection
	debug_level_option.selected = debug_manager.current_debug_level
	debug_level_option.item_selected.connect(_on_debug_level_changed)

func setup_category_checkboxes() -> void:
	"""Setup category checkboxes"""
	for category in debug_manager.debug_categories:
		var checkbox = CheckBox.new()
		checkbox.text = category
		checkbox.button_pressed = debug_manager.debug_categories[category]
		checkbox.toggled.connect(_on_category_toggled.bind(category))
		category_list.add_child(checkbox)

func _on_debug_level_changed(index: int) -> void:
	"""Handle debug level change"""
	debug_manager.set_level(index)
	update_status()

func _on_category_toggled(pressed: bool, category: String) -> void:
	"""Handle category toggle"""
	if pressed:
		debug_manager.enable_category(category)
	else:
		debug_manager.disable_category(category)
	update_status()

func update_status() -> void:
	"""Update status display"""
	var level_text = debug_manager._get_level_string(debug_manager.current_debug_level)
	var enabled_categories = []
	for category in debug_manager.debug_categories:
		if debug_manager.debug_categories[category]:
			enabled_categories.append(category)
	
	status_label.text = "Debug Level: %s\nEnabled Categories: %d/%d" % [
		level_text,
		enabled_categories.size(),
		debug_manager.debug_categories.size()
	]

# Quick preset buttons
func _on_preset_release_pressed() -> void:
	apply_preset(0)  # RELEASE

func _on_preset_basic_pressed() -> void:
	apply_preset(1)  # BASIC

func _on_preset_development_pressed() -> void:
	apply_preset(2)  # DEVELOPMENT

func _on_preset_full_debug_pressed() -> void:
	apply_preset(3)  # FULL_DEBUG

func apply_preset(preset_index: int) -> void:
	"""Apply a debug preset"""
	var debug_config = load("res://global_script/debug_config.gd")
	var config_settings = debug_config.get_preset_settings(preset_index)
	
	# Apply level
	debug_manager.set_level(config_settings.level)
	debug_level_option.selected = config_settings.level
	
	# Apply categories
	var categories = config_settings.categories
	for category in debug_manager.debug_categories:
		var enabled = categories.get(category, false)
		if enabled:
			debug_manager.enable_category(category)
		else:
			debug_manager.disable_category(category)
	
	# Update UI
	for i in range(category_list.get_child_count()):
		var checkbox = category_list.get_child(i) as CheckBox
		if checkbox:
			var category = checkbox.text
			checkbox.button_pressed = debug_manager.debug_categories[category]
	
	update_status()
	GlobalVariables.d_info("Applied debug preset: " + str(preset_index))
