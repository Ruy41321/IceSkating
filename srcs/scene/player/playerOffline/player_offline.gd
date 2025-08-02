class_name PlayerOffline
extends PlayerBase

#region OFFLINE SPECIFIC OVERRIDES

func setup_camera() -> void:
	"""Configure camera for offline player"""
	cam.activate()
	LevelManager.set_end_game_panel(cam.option_panel)

func handle_exit_tile() -> void:
	"""Handle reaching the exit tile"""
	can_move = false
	AudioManager.play_game_sfx("victory")
	play_fall_animation(true)

func _on_animation_finished(animation_name: String, has_win: bool) -> void:
	"""Handle animation finished events"""
	if animation_name == "fall":
		# Player fell into a hole - game over (loss)
		LevelManager.handle_end_game(has_win)

#endregion
