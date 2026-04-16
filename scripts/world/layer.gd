extends Parallax2D

## Builds16×16 tile chunks from editor `Logic` + dual-grid `Biome` grass, then optionally removes editor layers.

@export var chunk_script: Script

const GRASS_TILESET_SOURCE_ID: int = 1
const GRASS_LOGIC_ATLAS: Vector2i = Vector2i(0, 1)
const BIOME_LOCAL_OFFSET: Vector2 = Vector2(-32, -32)

## Atlas row 0..4 for masks 0001,0110, 1010, 1011, 1111 (TL,TR,BL,BR). Transform order matches LUT: transpose, flip_h, flip_v.
const _DUAL_BASE_MASKS: Array[int] = [1, 6, 10, 11, 15]

## Per mask 0..15: atlas row or -1 = leave cell empty.
## For example, 0000 -> -1, 0001 -> corner piece 
const _DUAL_ATLAS_ROW: Array[int] = [
	-1, 0, 0, 2, 0, 2, 1, 3, 0, 1, 2, 3, 2, 3, 3, 4
]

## Packed flip_h (bit0), flip_v (bit1), transpose (bit2) — see _dual_alternative_tile().
const _DUAL_TRANS_BITS: Array[int] = [
	0, 0, 1, 6, 2, 1, 0, 6, 3, 2, 0, 0, 4, 4, 2, 0
]

@export var remove_editor_layers_after_build: bool = true
@export_group("Chunk view")
@export var chunk_view_enabled: bool = true
@export var chunk_fade_duration: float = 0.5
@export var chunk_margin_tiles: int = 0
@export var chunk_debug_draw: bool = false


func _ready() -> void:
	if OS.is_debug_build():
		_assert_dual_lut()
	var source_logic: TileMapLayer = $Logic as TileMapLayer
	if source_logic == null:
		push_error("Layer: child TileMapLayer 'Logic' not found.")
		return
	var used: Rect2i = source_logic.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	_build_chunks_from_logic(source_logic, used)
	if remove_editor_layers_after_build:
		var biome: Node = get_node_or_null("Biome")
		source_logic.queue_free()
		if biome:
			biome.queue_free()


func _build_chunks_from_logic(source_logic: TileMapLayer, used: Rect2i) -> void:
	var chunk_w: int = TerrainChunkCodec.CHUNK_SIZE
	var chunk_h: int = TerrainChunkCodec.CHUNK_SIZE

	var top_left: Vector2i = TerrainChunkCodec.tile_to_chunk(used.position.x, used.position.y)
	var bottom_right: Vector2i = TerrainChunkCodec.tile_to_chunk(used.position.x + used.size.x - 1, used.position.y + used.size.y - 1)

	for chunk_y in range(top_left.y, bottom_right.y + 1):
		for chunk_x in range(top_left.x, bottom_right.x + 1):
			_spawn_chunk(source_logic, chunk_x, chunk_y, chunk_w, chunk_h)


func _spawn_chunk(source_logic: TileMapLayer, chunk_x: int, chunk_y: int, chunk_w: int, chunk_h: int) -> void:
	var ox: int = chunk_x * chunk_w
	var oy: int = chunk_y * chunk_h
	var grass_tileset: TileSet = _get_grass_tileset()

	var chunk := Node2D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_x, chunk_y]
	chunk.position = Vector2(float(ox * TerrainChunkCodec.TILE_SIZE_PX), float(oy * TerrainChunkCodec.TILE_SIZE_PX))
	if chunk_view_enabled:
		chunk.set_script(chunk_script)
		chunk.set("fade_duration", chunk_fade_duration)
		chunk.set("margin_tiles", chunk_margin_tiles)
		chunk.set("debug_draw", chunk_debug_draw)
	add_child(chunk)

	var chunk_logic := TileMapLayer.new()
	chunk_logic.name = "Logic"
	chunk_logic.tile_set = source_logic.tile_set
	chunk.add_child(chunk_logic)

	var chunk_biome := TileMapLayer.new()
	chunk_biome.name = "Biome"
	chunk_biome.tile_set = grass_tileset
	chunk_biome.position = BIOME_LOCAL_OFFSET
	chunk_biome.collision_enabled = false
	chunk.add_child(chunk_biome)

	for ly in chunk_h:
		for lx in chunk_w:
			var world_cell := Vector2i(ox + lx, oy + ly)
			var sid: int = source_logic.get_cell_source_id(world_cell)
			if sid != -1:
				chunk_logic.set_cell(
					Vector2i(lx, ly),
					sid,
					source_logic.get_cell_atlas_coords(world_cell),
					source_logic.get_cell_alternative_tile(world_cell)
				)

	var dual_w: int = chunk_w + 1
	var dual_h: int = chunk_h + 1
	for dy in dual_h:
		for dx in dual_w:
			var vx: int = ox + dx
			var vy: int = oy + dy
			var mask: int = _grass_corner_mask(source_logic, vx, vy)
			if mask == 0:
				continue
			var row: int = _DUAL_ATLAS_ROW[mask]
			if row < 0:
				continue
			var alt: int = _dual_alternative_tile(mask)
			chunk_biome.set_cell(
				Vector2i(dx, dy),
				GRASS_TILESET_SOURCE_ID,
				Vector2i(0, row),
				alt
			)


func _grass_corner_mask(source_logic: TileMapLayer, vx: int, vy: int) -> int:
	var tl: int = 1 if _cell_is_grass(source_logic, vx - 1, vy - 1) else 0
	var top_r: int = 1 if _cell_is_grass(source_logic, vx, vy - 1) else 0
	var bl: int = 1 if _cell_is_grass(source_logic, vx - 1, vy) else 0
	var br: int = 1 if _cell_is_grass(source_logic, vx, vy) else 0
	return tl << 3 | top_r << 2 | bl << 1 | br


func _cell_is_grass(layer: TileMapLayer, lx: int, ly: int) -> bool:
	var c := Vector2i(lx, ly)
	if layer.get_cell_source_id(c) == -1:
		return false
	return layer.get_cell_atlas_coords(c) == GRASS_LOGIC_ATLAS


func _dual_alternative_tile(mask: int) -> int:
	var bits: int = _DUAL_TRANS_BITS[mask]
	var fh: bool = (bits & 1) != 0
	var fv: bool = (bits & 2) != 0
	var tp: bool = (bits & 4) != 0
	var alt: int = 0
	if fh:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if fv:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if tp:
		alt |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return alt


func _get_grass_tileset() -> TileSet:
	var editor_biome: TileMapLayer = get_node_or_null("Biome") as TileMapLayer
	if editor_biome and editor_biome.tile_set:
		return editor_biome.tile_set
	return load("res://tilesets/grass.tres") as TileSet


func _assert_dual_lut() -> void:
	for m in range(16):
		var row: int = _DUAL_ATLAS_ROW[m]
		if row < 0:
			continue
		var base: int = _DUAL_BASE_MASKS[row]
		var bits: int = _DUAL_TRANS_BITS[m]
		var fh: bool = (bits & 1) != 0
		var fv: bool = (bits & 2) != 0
		var tp: bool = (bits & 4) != 0
		var got: int = _apply_corner_transform(base, tp, fh, fv)
		assert(got == m)


func _apply_corner_transform(m: int, transpose: bool, flip_h: bool, flip_v: bool) -> int:
	var tl: int = (m >> 3) & 1
	var top_r: int = (m >> 2) & 1
	var bl: int = (m >> 1) & 1
	var br: int = m & 1
	if transpose:
		var s: int = top_r
		top_r = bl
		bl = s
	if flip_h:
		var a: int = tl
		tl = top_r
		top_r = a
		a = bl
		bl = br
		br = a
	if flip_v:
		var b: int = tl
		tl = bl
		bl = b
		b = top_r
		top_r = br
		br = b
	return tl << 3 | top_r << 2 | bl << 1 | br
