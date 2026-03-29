extends Node

const PORT: int = 4242
const PRODUCTION_HOST: String = "tailwindserver.cody.dev"
const DEFAULT_PLAYER_SPAWN: Vector2 = Vector2(-183, 62)
## Horizontal gap between players so joiners do not spawn inside existing CharacterBody2D colliders (avoids moving-platform / snap bugs, see godot#91005).
const PLAYER_SPAWN_SPACING_X: float = 72.0

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")


func _enter_tree() -> void:
	var sp := get_parent().get_node_or_null("MultiplayerSpawner") as MultiplayerSpawner
	if sp:
		sp.spawn_function = _mp_spawn_player


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	await get_tree().process_frame
	_start_network_role()


func _exit_tree() -> void:
	go_offline()


func _start_network_role() -> void:
	if _is_dedicated_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		start_server()
		return
	connect_to_game_server()


func _is_dedicated_server() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("dedicated_server")


func resolve_server_host() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server-host="):
			return a.get_slice("=", 1).strip_edges()
	if OS.has_feature("editor"):
		return "127.0.0.1"
	if OS.is_debug_build():
		return "127.0.0.1"
	return PRODUCTION_HOST


func go_offline() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func start_server() -> void:
	go_offline()
	var enet := ENetMultiplayerPeer.new()
	if enet.create_server(PORT, 32) != OK:
		push_error("Failed to start server")
		return
	multiplayer.multiplayer_peer = enet
	multiplayer.server_relay = true
	print("Server running on port ", PORT)


func connect_to_game_server() -> void:
	if _is_dedicated_server():
		return
	var existing := multiplayer.multiplayer_peer
	if existing is ENetMultiplayerPeer:
		var st: int = existing.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_CONNECTED or st == MultiplayerPeer.CONNECTION_CONNECTING:
			return
	go_offline()
	var host := resolve_server_host()
	var enet := ENetMultiplayerPeer.new()
	if enet.create_client(host, PORT) != OK:
		push_error("Failed to create client for ", host)
		return
	multiplayer.multiplayer_peer = enet
	multiplayer.server_relay = true
	print("Connecting to ", host, ":", PORT)


func _on_connected_to_server() -> void:
	print("Connected to server")


func _on_connection_failed() -> void:
	push_warning("Connection to game server failed")
	go_offline()


func _on_server_disconnected() -> void:
	go_offline()


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawn_player_for_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var n := get_node_or_null(str(peer_id))
	if n:
		n.queue_free()


## MultiplayerSpawner calls this on every peer with the same `data` when the server invokes `spawn(data)`.
## Use a Dictionary so numeric peer ids are never interpreted as a spawnable-scene index.
func _mp_spawn_player(data: Variant) -> Node:
	var d := data as Dictionary
	var peer_id := int(d.get("peer_id", 0))
	var spawn_slot := int(d.get("spawn_slot", 0))
	var p: Node = PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	p.set("player_peer", peer_id)
	# MultiplayerSpawner runs this on every peer; authority must be set here so clients match the server (not only in _spawn_player_for_peer).
	p.global_position = DEFAULT_PLAYER_SPAWN + Vector2(spawn_slot * PLAYER_SPAWN_SPACING_X, 0.0)
	p.set_multiplayer_authority(peer_id, true)
	return p


func _spawn_player_for_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if get_node_or_null(str(peer_id)):
		return
	var sp := get_parent().get_node_or_null("MultiplayerSpawner") as MultiplayerSpawner
	if sp == null:
		push_error("MultiplayerSpawner missing next to Network")
		return
	var spawn_slot: int = get_child_count()
	var p: Node = sp.spawn({"peer_id": peer_id, "spawn_slot": spawn_slot})
	if p == null:
		push_error("MultiplayerSpawner.spawn failed for peer ", peer_id)
		return
