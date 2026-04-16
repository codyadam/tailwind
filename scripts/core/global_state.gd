extends Node

## When true (e.g. chat or other UI is capturing text), gameplay must ignore `game_*` input and related shortcuts.
var game_input_locked: bool = false

func set_game_input_locked(locked: bool) -> void:
	game_input_locked = locked
