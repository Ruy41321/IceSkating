# Debug System Documentation

## Overview
This project includes a comprehensive debug system that allows you to control debug output without removing debug code from your scripts.

## Quick Start

### 1. Basic Usage
In any script, you can use the global debug helper functions:

```gdscript
# Basic debug functions
GlobalVariables.d_error("Something went wrong!", "PLAYER_INPUT")
GlobalVariables.d_warning("This might be a problem", "MENU")
GlobalVariables.d_info("General information", "GENERAL")
GlobalVariables.d_debug("Detailed debug info", "GAME_STATE")
GlobalVariables.d_verbose("Very detailed trace", "LEVEL_MANAGEMENT")

# Category-specific shortcuts
GlobalVariables.d_player_input("Player moved to position " + str(position))
GlobalVariables.d_menu("Menu opened")
GlobalVariables.d_network("Connected to server")
GlobalVariables.d_map_gen("Map generated successfully")
GlobalVariables.d_game_state("Game state changed to: " + state_name)
GlobalVariables.d_level_mgmt("Loading level: " + level_name)
```

### 2. Configuration
Edit `global_script/debug_config.gd` to change debug settings:

```gdscript
# Choose your debug preset
const CURRENT_PRESET: DebugPreset = DebugPreset.DEVELOPMENT
```

## Available Presets

### RELEASE
- **Level**: NONE (no debug output)
- **Use**: Final builds, production releases

### BASIC  
- **Level**: WARNING (only errors and warnings)
- **Categories**: Only GENERAL enabled
- **Use**: Light debugging, basic error checking

### DEVELOPMENT
- **Level**: DEBUG (detailed debugging)
- **Categories**: Most common categories enabled
- **Use**: Regular development work

### FULL_DEBUG
- **Level**: VERBOSE (everything)
- **Categories**: All categories enabled
- **Use**: Deep debugging, troubleshooting complex issues

### CUSTOM
- **Level**: Set in CUSTOM_DEBUG_LEVEL
- **Categories**: Set in CUSTOM_CATEGORIES
- **Use**: Your own custom configuration

## Debug Categories

| Category | Description |
|----------|-------------|
| GENERAL | General debug messages |
| PLAYER_INPUT | Player input and movement |
| MENU | Menu and UI interactions |
| NETWORK | Multiplayer networking |
| MAP_GENERATION | Map loading and generation |
| GAME_STATE | Game state changes |
| ANIMATION | Animation system |
| LEVEL_MANAGEMENT | Level transitions |
| AUTHENTICATION | User authentication |
| ROOM_MANAGEMENT | Room creation/joining |

## Advanced Usage

### Direct DebugManager Access
```gdscript
# Get the debug manager
var debug_manager = get_node("/root/DebugManager")

# Use it directly
debug_manager.error("Critical error!", "NETWORK")
debug_manager.enable_category("ANIMATION")
debug_manager.set_level(DebugManager.Level.VERBOSE)
debug_manager.print_debug_status()
```

### Runtime Configuration
```gdscript
# Enable/disable categories at runtime
var debug_manager = get_node("/root/DebugManager")
debug_manager.enable_category("PLAYER_INPUT")
debug_manager.disable_category("MENU")

# Change debug level at runtime
debug_manager.set_level(DebugManager.Level.DEBUG)

# Enable all categories for debugging
debug_manager.enable_all_categories()

# Disable all for clean output
debug_manager.disable_all_categories()
```

## Best Practices

### 1. Use Appropriate Categories
```gdscript
# Good - specific category
GlobalVariables.d_player_input("Player direction changed: " + str(direction))

# Less good - generic category
GlobalVariables.d_debug("Player direction changed: " + str(direction), "GENERAL")
```

### 2. Use Appropriate Debug Levels
```gdscript
# Errors - for critical issues that break functionality
GlobalVariables.d_error("Failed to load map file", "MAP_GENERATION")

# Warnings - for potential issues
GlobalVariables.d_warning("Player position out of bounds, clamping", "PLAYER_INPUT")

# Info - for important events
GlobalVariables.d_info("Level completed", "GAME_STATE")

# Debug - for detailed debugging
GlobalVariables.d_debug("Checking collision at " + str(position), "PLAYER_INPUT")

# Verbose - for trace-level details
GlobalVariables.d_verbose("Processing input event: " + str(event), "PLAYER_INPUT")
```

### 3. Include Relevant Context
```gdscript
# Good - includes context
GlobalVariables.d_debug("Player health: " + str(health) + "/" + str(max_health), "GAME_STATE")

# Less helpful
GlobalVariables.d_debug("Health updated", "GAME_STATE")
```

## Configuration Examples

### For Final Release
```gdscript
const CURRENT_PRESET: DebugPreset = DebugPreset.RELEASE
```

### For Development
```gdscript
const CURRENT_PRESET: DebugPreset = DebugPreset.DEVELOPMENT
```

### For Network Debugging
```gdscript
const CURRENT_PRESET: DebugPreset = DebugPreset.CUSTOM
const CUSTOM_DEBUG_LEVEL = Level.VERBOSE
const CUSTOM_CATEGORIES = {
	"NETWORK": true,
	"AUTHENTICATION": true,
	"ROOM_MANAGEMENT": true,
	"GENERAL": true,
	# Disable others for focused debugging
	"PLAYER_INPUT": false,
	"MENU": false,
	"MAP_GENERATION": false,
	"GAME_STATE": false,
	"ANIMATION": false,
	"LEVEL_MANAGEMENT": false
}
```

## Migration from `print()`

Replace existing `print()` statements:

```gdscript
# Old way
print("Player moved to: ", position)

# New way - choose appropriate level and category
GlobalVariables.d_debug("Player moved to: " + str(position), "PLAYER_INPUT")

# Or use the shortcut
GlobalVariables.d_player_input("Player moved to: " + str(position))
```

## Performance Notes

- Debug functions have minimal overhead when disabled
- String concatenation still occurs, so for performance-critical code consider:

```gdscript
# Performance-critical code pattern
if DebugManager and DebugManager.current_debug_level >= DebugManager.Level.DEBUG:
	var debug_manager = get_node("/root/DebugManager")
	if debug_manager.debug_categories.get("PLAYER_INPUT", false):
		GlobalVariables.d_player_input("Expensive debug calculation: " + expensive_function())
```

## Files in the Debug System

- `global_script/debug_manager.gd` - Core debug functionality
- `global_script/debug_config.gd` - Configuration presets
- `global_script/global_variables.gd` - Helper functions (d_debug, d_error, etc.)
- `project.godot` - DebugManager configured as autoload
