extends Object
class_name TerrainChunkCodec

const CHUNK_SIZE: int = 16
const CHUNK_CELLS: int = 256
const TILE_SIZE_PX: int = 64

const FNV_OFFSET: int = 0x811C9DC5
const FNV_PRIME: int = 0x01000193


static func tile_to_chunk(tx: int, ty: int) -> Vector2i:
	return Vector2i(int(floor(tx / float(CHUNK_SIZE))), int(floor(ty / float(CHUNK_SIZE))))


static func chunk_origin_tile(cx: int, cy: int) -> Vector2i:
	return Vector2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE)


static func fnv1a32(data: PackedByteArray) -> int:
	var h: int = FNV_OFFSET
	for i in data.size():
		h = (h ^ int(data[i])) * FNV_PRIME
		h = h & 0xFFFFFFFF
	return h


static func empty_chunk_hash() -> int:
	var zeros := PackedByteArray()
	zeros.resize(CHUNK_CELLS)
	return fnv1a32(zeros)


## Row-major: index = ly * CHUNK_SIZE + lx; cell at world tile (ox+lx, oy+ly).
static func read_chunk_bytes(layer: TileMapLayer, cx: int, cy: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(CHUNK_CELLS)
	var ox := cx * CHUNK_SIZE
	var oy := cy * CHUNK_SIZE
	var i := 0
	for ly in CHUNK_SIZE:
		for lx in CHUNK_SIZE:
			var c := Vector2i(ox + lx, oy + ly)
			out[i] = 1 if layer.get_cell_tile_data(c) != null else 0
			i += 1
	return out


static func apply_chunk_bytes(
	layer: TileMapLayer,
	cx: int,
	cy: int,
	bytes: PackedByteArray,
	terrain_set: int,
	terrain_fill: int
) -> void:
	if bytes.size() != CHUNK_CELLS:
		push_error("TerrainChunkCodec.apply_chunk_bytes: expected %d bytes" % CHUNK_CELLS)
		return
	var ox := cx * CHUNK_SIZE
	var oy := cy * CHUNK_SIZE
	var to_clear: Array[Vector2i] = []
	var to_fill: Array[Vector2i] = []
	var i := 0
	for ly in CHUNK_SIZE:
		for lx in CHUNK_SIZE:
			var c := Vector2i(ox + lx, oy + ly)
			if bytes[i] != 0:
				to_fill.append(c)
			else:
				to_clear.append(c)
			i += 1
	if not to_clear.is_empty():
		layer.set_cells_terrain_connect(to_clear, terrain_set, -1)
	to_fill.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	if not to_fill.is_empty():
		layer.set_cells_terrain_connect(to_fill, terrain_set, terrain_fill)
