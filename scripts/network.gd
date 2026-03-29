extends Node

func _ready():
    if DisplayServer.get_name() == "headless":
        start_server()

func start_server():
    var peer := ENetMultiplayerPeer.new()
    var result := peer.create_server(4242, 32)
    if result != OK:
        push_error("Failed to start server")
        return
    multiplayer.multiplayer_peer = peer
    print("Server running on port 4242")