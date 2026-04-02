extends Node

const DEV_PORT: int = 4242
const PROD_PORT: int = 443
const PRODUCTION_HOST: String = "tailwindserver.codya.dev"
const DEFAULT_PLAYER_SPAWN: Vector2 = Vector2(0, 0)
const PLAYER_SPAWN_SPACING_X: float = 72.0

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

#region handlers

func _ready() -> void:
	spawner.spawn_function = _spawn_function
	multiplayer.connected_to_server.connect(_after_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if Utils.is_dedicated_server():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		start_server()
		return
	connect_to_game_server()


func _exit_tree() -> void:
	go_offline()


func _unhandled_input(event: InputEvent) -> void:
	if Utils.is_dedicated_server():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_offline_mode()
		get_viewport().set_input_as_handled()


func _after_connected_to_server() -> void:
	print("Connected to server")
	Events.after_connected.emit()


func _on_connection_failed() -> void:
	print("Connection to game server failed")
	Events.after_disconnected.emit()
	go_offline()


func _on_server_disconnected() -> void:
	Events.after_disconnected.emit()
	go_offline()

func _on_peer_connected(peer_id: int) -> void:
	Events.after_server_player_joined.emit(peer_id)
	if not multiplayer.is_server():
		return
	_spawn_player_for_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	Events.after_server_player_left.emit(peer_id)
	if not multiplayer.is_server():
		return
	var n := get_node_or_null(str(peer_id))
	if n:
		n.queue_free()


#region offline mode

func go_offline() -> void:
	print("Going offline")
	var peer := multiplayer.multiplayer_peer
	if peer and not (peer is OfflineMultiplayerPeer):
		_clear_spawned_players()
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if not Utils.is_dedicated_server():
		_spawn_player_for_peer(multiplayer.get_unique_id())


func _toggle_offline_mode() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and not (peer is OfflineMultiplayerPeer):
		go_offline()
		return
	connect_to_game_server()


#region initializing

func connect_to_game_server() -> void:
	if Utils.is_dedicated_server():
		return
	var existing := multiplayer.multiplayer_peer
	if existing and not (existing is OfflineMultiplayerPeer):
		var st: int = existing.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_CONNECTED or st == MultiplayerPeer.CONNECTION_CONNECTING:
			return
	if existing:
		_clear_spawned_players()
		existing.close()
	var url := resolve_client_url()
	var wsm := WebSocketMultiplayerPeer.new()
	if wsm.create_client(url) != OK:
		push_error("Failed to create client for ", url)
		return
	multiplayer.multiplayer_peer = wsm
	multiplayer.server_relay = true
	print("Connecting to ", url)

func _clear_spawned_players() -> void:
	for child in get_children():
		if child is Player:
			child.queue_free()

#region spawning

func _spawn_function(peer_id: int) -> Node:
	var p: Node = PLAYER_SCENE.instantiate()
	p.name = str(peer_id)
	p.global_position = DEFAULT_PLAYER_SPAWN
	p.set_multiplayer_authority(peer_id, true)
	return p

func _spawn_player_for_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if get_node_or_null(str(peer_id)):
		return
	var p: Node = spawner.spawn(peer_id)
	if p == null:
		push_error("MultiplayerSpawner.spawn failed for peer ", peer_id)
		return

#region dedicated server

func start_server() -> void:
	var wsm := WebSocketMultiplayerPeer.new()
	if wsm.create_server(DEV_PORT) != OK:
		push_error("Failed to start server")
		return
	multiplayer.multiplayer_peer = wsm
	multiplayer.server_relay = true
	print("Server running WebSocket on port ", DEV_PORT)

#region url resolution

func resolve_server_host() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server-host="):
			return a.get_slice("=", 1).strip_edges()
	if OS.has_feature("editor"):
		return "127.0.0.1"
	if OS.is_debug_build():
		return "127.0.0.1"
	return PRODUCTION_HOST


## Host part for ws/wss URLs (brackets for IPv6 literals).
func _host_for_websocket_url(host: String) -> String:
	if host.begins_with("["):
		return host
	if ":" in host:
		return "[%s]" % host
	return host


func _is_loopback_host(host: String) -> bool:
	var h := host.to_lower()
	return h == "127.0.0.1" or h == "localhost" or h == "::1"


## Full WebSocket URL for [method connect_to_game_server]. Override with `--server-url=wss://host:443`.
## Browsers on HTTPS need `wss://` to a TLS-terminated endpoint; plain `ws://` is fine for local/desktop tests.
func resolve_client_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server-url="):
			return a.get_slice("=", 1).strip_edges()
	var host := resolve_server_host()
	var scheme := "ws"
	var port := DEV_PORT
	if OS.has_feature("web") and not _is_loopback_host(host):
		scheme = "wss"
		port = PROD_PORT
	var h := _host_for_websocket_url(host)
	return "%s://%s:%d" % [scheme, h, port]
