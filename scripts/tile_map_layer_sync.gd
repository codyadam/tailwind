extends TileMapLayer

@onready var sync_timer: Timer = $Timer
@export var terrain_set_id: int = 0
@export var terrain_id: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sync_timer.timeout.connect(_on_sync_check)
	Events.on_connected.connect(_on_sync_check)
	_on_sync_check()

func _on_sync_check() -> void:
	if multiplayer.is_server():
		return
	var tilemap_hash = _get_tilemap_hash()
	_request_sync_tilemap.rpc_id(1, tilemap_hash)

@rpc("any_peer", "call_remote", "reliable")
func _request_sync_tilemap(input_hash: int) -> void:
	var tilemap_hash = _get_tilemap_hash()
	if tilemap_hash == input_hash:
		return
	var sender = multiplayer.get_remote_sender_id()
	var tiles_positions := get_used_cells()
	_override_tilemap.rpc_id(sender, tiles_positions)

@rpc("authority", "call_remote", "reliable")
func _override_tilemap(tiles_positions: Array[Vector2i]) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority():
		return
	print("Syncing tilemap")
	clear()
	for pos in tiles_positions:
		set_cells_terrain_connect([pos], terrain_set_id, terrain_id)


func _get_tilemap_hash() -> int:
	var hash_result := 5381
	for cell in get_used_cells():
		var atlas_coords := get_cell_atlas_coords(cell)
		# Mix cell coordinates and terrain for hash determinism
		hash_result = int(((hash_result << 5) + hash_result) + int(cell.x) * 31 + int(cell.y) * 17 + int(atlas_coords.x) * 13 + int(atlas_coords.y) * 7)
	return hash_result
