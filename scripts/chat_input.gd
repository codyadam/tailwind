extends LineEdit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text_submitted.connect(_on_text_submitted)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _on_focus_entered() -> void:
	GlobalState.set_game_input_locked(true)


func _on_focus_exited() -> void:
	GlobalState.set_game_input_locked(false)


func _exit_tree() -> void:
	GlobalState.set_game_input_locked(false)


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_focus_chat"):
		if has_focus():
			return
		# consume the input
		get_viewport().set_input_as_handled()
		grab_focus()
	if Input.is_action_just_pressed("ui_cancel"):
		if not has_focus():
			return
		# consume the input
		get_viewport().set_input_as_handled()
		release_focus()

func _on_text_submitted(_new_text: String) -> void:
	text = ""
	release_focus()
