extends LineEdit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text_submitted.connect(_on_text_submitted)

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_focus_chat"):
		if has_focus():
			return
		grab_focus()
	if Input.is_action_just_pressed("ui_cancel"):
		if not has_focus():
			return
		release_focus()

func _on_text_submitted(_new_text: String) -> void:
	text = ""
