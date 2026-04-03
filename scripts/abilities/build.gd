extends Ability

@export var terrain_set_id: int = 0
@export var terrain_id: int = 0

@onready var tilemap: TileMapLayer = $"/root/Main/Terrain/TileMapLayer"
@onready var player: Player = $"../.."

var label: String = "🔨"
var controls_helper_text: String = "Left Click - Place block\nRight Click - Remove block"


func _process(_delta: float) -> void:
	var place_block := Input.is_action_pressed("game_primary")
	var remove_block := Input.is_action_pressed("game_secondary")
	if not place_block and not remove_block:
		return

	if not tilemap:
		return

	if player and not player._is_controlling_locally():
		return

	var mouse_world := tilemap.get_global_mouse_position()
	var map_coords := tilemap.local_to_map(tilemap.to_local(mouse_world))
	var is_empty := tilemap.get_cell_tile_data(map_coords) == null

	var offline := multiplayer.multiplayer_peer is OfflineMultiplayerPeer

	if place_block and is_empty:
		if offline:
			tilemap.set_cells_terrain_connect([map_coords], terrain_set_id, terrain_id)
		elif multiplayer.is_server():
			tilemap.server_apply_build(map_coords, true, multiplayer.get_unique_id())
		else:
			tilemap.set_cells_terrain_connect([map_coords], terrain_set_id, terrain_id)
			tilemap.client_request_place.rpc_id(1, map_coords)
	elif remove_block and not is_empty:
		if offline:
			tilemap.set_cells_terrain_connect([map_coords], terrain_set_id, -1)
		elif multiplayer.is_server():
			tilemap.server_apply_build(map_coords, false, multiplayer.get_unique_id())
		else:
			tilemap.set_cells_terrain_connect([map_coords], terrain_set_id, -1)
			tilemap.client_request_remove.rpc_id(1, map_coords)
