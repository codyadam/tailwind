extends Node

@export var terrain_set_id: int = 0
@export var terrain_id: int = 0

@onready var tilemap: TileMapLayer = $"/root/MainScene/Terrain/TileMapLayer"
@onready var player: Player = $"../.."


func _process(_delta: float) -> void:
	var place_block := Input.is_action_pressed("game_primary")
	var remove_block := Input.is_action_pressed("game_secondary")
	if not place_block and not remove_block:
		return

	if not tilemap:
		print("Tilemap not found", tilemap, $"/root/MainScene/Terrain/TileMapLayer")
		return

	if player and not player._is_controlling_locally():
		return

	var mouse_world := tilemap.get_global_mouse_position()
	var map_coords := tilemap.local_to_map(tilemap.to_local(mouse_world))
	var is_empty := tilemap.get_cell_tile_data(map_coords) == null

	if place_block and is_empty:
		_request_place_block.rpc_id(1, map_coords)
		_place_block(map_coords)
	elif remove_block and not is_empty:
		_request_remove_block.rpc_id(1, map_coords)
		_remove_block(map_coords)


@rpc("any_peer", "call_remote", "unreliable")
func _request_place_block(map_coords: Vector2i) -> void:
	_place_block.rpc(map_coords)

@rpc("any_peer", "call_local", "unreliable")
func _place_block(map_coords: Vector2i) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if tilemap == null:
		return
	tilemap.set_cells_terrain_connect([map_coords], terrain_set_id, terrain_id)

@rpc("any_peer", "call_remote", "unreliable")
func _request_remove_block(map_coords: Vector2i) -> void:
	_remove_block.rpc(map_coords)

@rpc("any_peer", "call_local", "unreliable")
func _remove_block(map_coords: Vector2i) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if tilemap == null:
		return
	tilemap.set_cells_terrain_connect([map_coords], terrain_set_id, -1)
