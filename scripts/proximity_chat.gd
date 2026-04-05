extends Label

@onready var timer: Timer = $Timer

@export var player: Player

func _ready() -> void:
	text = ""
	timer.timeout.connect(_on_timer_timeout)
	if player._is_controlling_locally():
		var chat_input = get_node_or_null("/root/Main/UI/Control/ChatInput") as LineEdit
		if chat_input:
			chat_input.text_submitted.connect(_on_text_submitted)

func _on_text_submitted(new_text: String) -> void:
	if new_text.is_empty():
		return
	_send_chat_message.rpc(new_text)

func _on_timer_timeout() -> void:
	text = ""

@rpc("any_peer", "call_local", "unreliable")
func _send_chat_message(message: String) -> void:
	timer.start()
	text = message
