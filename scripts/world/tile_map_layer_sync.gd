extends TileMapLayer

const _SNAPSHOT_HEADER: int = 16 # 4x int32: cx, cy, version, hash

@onready var sync_timer: Timer = $Timer

@export var terrain_set_id: int = 0
@export var terrain_id: int = 0
## Chunk half-extent; total interest is (2 * (interest_radius_chunks + interest_halo_chunks) + 1)² chunks (default 3×3 = 9).
@export var interest_radius_chunks: int = 1
@export var interest_halo_chunks: int = 0
## Max chunk snapshots the server sends per frame (manifest response).
@export_range(1, 32) var server_snapshots_per_frame: int = 4
## Max chunk snapshots the client applies per frame (avoids one-frame hitches).
@export_range(1, 32) var client_snapshots_per_frame: int = 1
## When building the manifest, process at most this many chunks per frame (0 = all in one frame).
@export_range(0, 256) var manifest_chunks_per_frame: int = 16

var _empty_chunk_hash: int = 0

var _server_snapshot_outbox: Array[Dictionary] = []
var _client_snapshot_inbox: Array[PackedByteArray] = []

var _manifest_building: bool = false
var _manifest_chunk_list: Array[Vector2i] = []
var _manifest_chunk_i: int = 0
var _manifest_spb: StreamPeerBuffer

# Server-only: chunk key -> { "version": int, "hash": int }
var _server_chunk_index: Dictionary = {}

# Server-only: peer_id -> Dictionary[Vector2i, bool]
var _server_peer_chunks: Dictionary = {}

# Client-only: chunk key -> { "version": int, "hash": int }
var _client_chunk_mirror: Dictionary = {}


func _ready() -> void:
	set_multiplayer_authority(1, true)
	_empty_chunk_hash = TerrainChunkCodec.empty_chunk_hash()
	sync_timer.timeout.connect(_on_sync_timer)
	Events.after_connected.connect(_on_after_connected)
	Events.after_server_player_joined.connect(_on_server_player_joined)
	set_process(true)
	_on_after_connected()


func _on_server_player_joined(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var nw := get_node_or_null("/root/Main/Network") as Node
	if nw == null:
		return
	var spawn: Vector2 = nw.player_spawn_point.global_position
	var center_tile := local_to_map(to_local(spawn))
	_server_send_snapshots_around_tile(peer_id, center_tile)


func _server_send_snapshots_around_tile(peer_id: int, center_tile: Vector2i) -> void:
	var r := interest_radius_chunks + interest_halo_chunks
	var cc := TerrainChunkCodec.tile_to_chunk(center_tile.x, center_tile.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var ch := Vector2i(cc.x + dx, cc.y + dy)
			var st := _server_chunk_state(ch)
			var bytes := TerrainChunkCodec.read_chunk_bytes(self, ch.x, ch.y)
			var snap := _pack_snapshot(ch.x, ch.y, st.version, st.hash, bytes)
			_server_snapshot_outbox.append({"peer_id": peer_id, "payload": snap})


func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		_server_refresh_peer_interests()
		_server_flush_snapshot_outbox()
	else:
		_client_refresh_interest_chunks()
		_client_continue_manifest_build()
		_client_apply_snapshot_inbox()


func _server_flush_snapshot_outbox() -> void:
	var n := mini(server_snapshots_per_frame, _server_snapshot_outbox.size())
	for _i in n:
		var item: Dictionary = _server_snapshot_outbox.pop_front()
		_rpc_chunk_snapshot.rpc_id(int(item.peer_id), item.payload)


func _client_apply_snapshot_inbox() -> void:
	for _i in mini(client_snapshots_per_frame, _client_snapshot_inbox.size()):
		_apply_chunk_snapshot_payload(_client_snapshot_inbox.pop_front())


func _client_continue_manifest_build() -> void:
	if not _manifest_building:
		return
	var budget := manifest_chunks_per_frame
	if budget <= 0:
		budget = _manifest_chunk_list.size() - _manifest_chunk_i
	while _manifest_chunk_i < _manifest_chunk_list.size() and budget > 0:
		var ch: Vector2i = _manifest_chunk_list[_manifest_chunk_i]
		if not _client_chunk_mirror.has(ch):
			_client_chunk_mirror[ch] = {"version": 0, "hash": _empty_chunk_hash}
		var e: Dictionary = _client_chunk_mirror[ch]
		var live_bytes := TerrainChunkCodec.read_chunk_bytes(self, ch.x, ch.y)
		var live_hash := TerrainChunkCodec.fnv1a32(live_bytes)
		_manifest_spb.put_32(ch.x)
		_manifest_spb.put_32(ch.y)
		_manifest_spb.put_u32(int(e.version))
		_manifest_spb.put_u32(live_hash)
		_manifest_chunk_i += 1
		budget -= 1
	if _manifest_chunk_i >= _manifest_chunk_list.size():
		_rpc_submit_manifest.rpc_id(1, _manifest_spb.data_array)
		_manifest_building = false


func _client_interest_chunk_list() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var network := get_node_or_null("/root/Main/Network")
	if network == null:
		return out
	var player := network.get_node_or_null(str(multiplayer.get_unique_id()))
	if player == null or not (player is Node2D):
		return out
	var tile := local_to_map(to_local((player as Node2D).global_position))
	var r := interest_radius_chunks + interest_halo_chunks
	var cc := TerrainChunkCodec.tile_to_chunk(tile.x, tile.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			out.append(Vector2i(cc.x + dx, cc.y + dy))
	return out


func _server_refresh_peer_interests() -> void:
	var network := get_node_or_null("/root/Main/Network")
	if network == null:
		return
	var peer_ids: Array[int] = []
	for p in multiplayer.get_peers():
		peer_ids.append(p)
	peer_ids.append(1)
	for peer_id in peer_ids:
		var player := network.get_node_or_null(str(peer_id))
		if player == null or not (player is Node2D):
			continue
		var tile := local_to_map(to_local((player as Node2D).global_position))
		var r := interest_radius_chunks + interest_halo_chunks
		var cc := TerrainChunkCodec.tile_to_chunk(tile.x, tile.y)
		var chunks: Dictionary = {}
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				chunks[Vector2i(cc.x + dx, cc.y + dy)] = true
		_server_peer_chunks[peer_id] = chunks


func _client_refresh_interest_chunks() -> void:
	var network := get_node_or_null("/root/Main/Network")
	if network == null:
		return
	var player := network.get_node_or_null(str(multiplayer.get_unique_id()))
	if player == null or not (player is Node2D):
		return
	var tile := local_to_map(to_local((player as Node2D).global_position))
	var r := interest_radius_chunks + interest_halo_chunks
	var cc := TerrainChunkCodec.tile_to_chunk(tile.x, tile.y)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var ch := Vector2i(cc.x + dx, cc.y + dy)
			if not _client_chunk_mirror.has(ch):
				_client_chunk_mirror[ch] = {"version": 0, "hash": _empty_chunk_hash}


func _server_chunk_state(chunk: Vector2i) -> Dictionary:
	if _server_chunk_index.has(chunk):
		return _server_chunk_index[chunk]
	return {"version": 0, "hash": _empty_chunk_hash}


func _server_refresh_chunk_after_edit(chunk: Vector2i) -> void:
	var bytes := TerrainChunkCodec.read_chunk_bytes(self, chunk.x, chunk.y)
	var h := TerrainChunkCodec.fnv1a32(bytes)
	var has_tile := false
	for i in bytes.size():
		if bytes[i] != 0:
			has_tile = true
			break
	if not has_tile:
		_server_chunk_index.erase(chunk)
		return
	if _server_chunk_index.has(chunk):
		var e: Dictionary = _server_chunk_index[chunk]
		e.version = int(e.version) + 1
		e.hash = h
	else:
		_server_chunk_index[chunk] = {"version": 1, "hash": h}


func _server_peers_for_chunk(chunk: Vector2i, acting_peer: int) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	out.append(acting_peer)
	seen[acting_peer] = true
	for peer_id in _server_peer_chunks:
		var chunks: Dictionary = _server_peer_chunks[peer_id]
		if chunks.has(chunk) and not seen.has(peer_id):
			seen[peer_id] = true
			out.append(peer_id)
	return out


func server_apply_build(map_coords: Vector2i, placing: bool, from_peer: int) -> void:
	if not multiplayer.is_server():
		return
	if placing:
		if get_cell_tile_data(map_coords) != null:
			return
		set_cells_terrain_connect([map_coords], terrain_set_id, terrain_id)
	else:
		if get_cell_tile_data(map_coords) == null:
			return
		set_cells_terrain_connect([map_coords], terrain_set_id, -1)
	var ch := TerrainChunkCodec.tile_to_chunk(map_coords.x, map_coords.y)
	_server_refresh_chunk_after_edit(ch)
	var st := _server_chunk_state(ch)
	var ver: int = int(st.version)
	for pid in _server_peers_for_chunk(ch, from_peer):
		if pid == multiplayer.get_unique_id():
			_client_apply_replicate(map_coords, placing, ver)
		else:
			_rpc_replicate_terrain.rpc_id(pid, map_coords, placing, ver)


@rpc("any_peer", "call_remote", "unreliable")
func client_request_place(map_coords: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	var from_peer := multiplayer.get_remote_sender_id()
	if from_peer == 0:
		from_peer = multiplayer.get_unique_id()
	server_apply_build(map_coords, true, from_peer)


@rpc("any_peer", "call_remote", "unreliable")
func client_request_remove(map_coords: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	var from_peer := multiplayer.get_remote_sender_id()
	if from_peer == 0:
		from_peer = multiplayer.get_unique_id()
	server_apply_build(map_coords, false, from_peer)


func _client_apply_replicate(map_coords: Vector2i, placing: bool, chunk_version: int) -> void:
	if placing:
		set_cells_terrain_connect([map_coords], terrain_set_id, terrain_id)
	else:
		set_cells_terrain_connect([map_coords], terrain_set_id, -1)
	var ch := TerrainChunkCodec.tile_to_chunk(map_coords.x, map_coords.y)
	_client_update_mirror_from_layer(ch, chunk_version)


func _client_update_mirror_from_layer(chunk: Vector2i, chunk_version: int) -> void:
	var bytes := TerrainChunkCodec.read_chunk_bytes(self, chunk.x, chunk.y)
	var h := TerrainChunkCodec.fnv1a32(bytes)
	_client_chunk_mirror[chunk] = {"version": chunk_version, "hash": h}


@rpc("authority", "call_remote", "reliable")
func _rpc_replicate_terrain(map_coords: Vector2i, placing: bool, chunk_version: int) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_client_apply_replicate(map_coords, placing, chunk_version)


func _on_after_connected() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if not multiplayer.is_server():
		_on_sync_timer()


func _on_sync_timer() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		return
	if _manifest_building:
		return
	_manifest_chunk_list = _client_interest_chunk_list()
	if _manifest_chunk_list.is_empty():
		return
	print("Tilemap chunk sync: timer fired, sending manifest for %d interest chunks" % _manifest_chunk_list.size())
	_manifest_spb = StreamPeerBuffer.new()
	_manifest_spb.put_u32(_manifest_chunk_list.size())
	_manifest_chunk_i = 0
	_manifest_building = true
	if manifest_chunks_per_frame <= 0:
		while _manifest_chunk_i < _manifest_chunk_list.size():
			var ch: Vector2i = _manifest_chunk_list[_manifest_chunk_i]
			if not _client_chunk_mirror.has(ch):
				_client_chunk_mirror[ch] = {"version": 0, "hash": _empty_chunk_hash}
			var e: Dictionary = _client_chunk_mirror[ch]
			var live_bytes := TerrainChunkCodec.read_chunk_bytes(self, ch.x, ch.y)
			var live_hash := TerrainChunkCodec.fnv1a32(live_bytes)
			_manifest_spb.put_32(ch.x)
			_manifest_spb.put_32(ch.y)
			_manifest_spb.put_u32(int(e.version))
			_manifest_spb.put_u32(live_hash)
			_manifest_chunk_i += 1
		_rpc_submit_manifest.rpc_id(1, _manifest_spb.data_array)
		_manifest_building = false


func _pack_snapshot(cx: int, cy: int, version: int, hash_value: int, cells: PackedByteArray) -> PackedByteArray:
	var spb := StreamPeerBuffer.new()
	spb.put_32(cx)
	spb.put_32(cy)
	spb.put_u32(version)
	spb.put_u32(hash_value)
	spb.put_data(cells)
	return spb.data_array


@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_manifest(data: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var spb := StreamPeerBuffer.new()
	spb.data_array = data
	if data.size() < 4:
		return
	var n := int(spb.get_u32())
	for _i in n:
		if spb.get_position() + 16 > data.size():
			return
		var cx := spb.get_32()
		var cy := spb.get_32()
		var cv := int(spb.get_u32())
		var chash := int(spb.get_u32())
		var chunk := Vector2i(cx, cy)
		var srv := _server_chunk_state(chunk)
		if int(srv.version) == cv and int(srv.hash) == chash:
			continue
		var bytes := TerrainChunkCodec.read_chunk_bytes(self, cx, cy)
		var snap := _pack_snapshot(cx, cy, int(srv.version), int(srv.hash), bytes)
		_server_snapshot_outbox.append({"peer_id": sender, "payload": snap})


@rpc("authority", "call_remote", "reliable")
func _rpc_chunk_snapshot(payload: PackedByteArray) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_client_snapshot_inbox.append(payload)


func _apply_chunk_snapshot_payload(payload: PackedByteArray) -> void:
	if payload.size() < _SNAPSHOT_HEADER + TerrainChunkCodec.CHUNK_CELLS:
		return
	var spb := StreamPeerBuffer.new()
	spb.data_array = payload
	var cx := spb.get_32()
	var cy := spb.get_32()
	var ver := int(spb.get_u32())
	var h := int(spb.get_u32())
	var cells := payload.slice(_SNAPSHOT_HEADER, payload.size())
	TerrainChunkCodec.apply_chunk_bytes(self, cx, cy, cells, terrain_set_id, terrain_id)
	_client_chunk_mirror[Vector2i(cx, cy)] = {"version": ver, "hash": h}
