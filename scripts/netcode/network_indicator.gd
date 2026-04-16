extends Label


func _ready() -> void:
	_update_status_label()


func _process(_delta: float) -> void:
	_update_status_label()


func _update_status_label() -> void:
	var peer := multiplayer.multiplayer_peer
	var connected_peers := multiplayer.get_peers().size()
	var status := MultiplayerPeer.CONNECTION_DISCONNECTED

	if peer:
		status = peer.get_connection_status()

	var emoji := "🔴"
	var state_text := "Offline"

	if multiplayer.is_server() and peer is OfflineMultiplayerPeer:
		emoji = "🔴"
		state_text = "Offline"
	elif multiplayer.is_server() and peer:
		emoji = "🟢"
		state_text = "Online (Host)"
	elif status == MultiplayerPeer.CONNECTION_CONNECTED:
		emoji = "🟢"
		state_text = "Online"
	elif status == MultiplayerPeer.CONNECTION_CONNECTING:
		emoji = "🟡"
		state_text = "Connecting"

	text = "%s %s | Players: %d" % [emoji, state_text, connected_peers]
