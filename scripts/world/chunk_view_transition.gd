extends Node2D

## Per-chunk fade/cull: expanded camera rect vs this node's footprint in canvas space; modulate + `visible`.

@export var fade_duration: float = 0.5
@export var margin_tiles: int = 0

@export_group("Debug")
@export var debug_draw: bool = false
@export var debug_chunk_color: Color = Color(0.2, 1.0, 0.35, 0.95)
@export var debug_view_color: Color = Color(0.2, 0.85, 1.0, 0.95)
@export var debug_line_width: float = 4.0

var _was_inside: bool = false
var _tween: Tween


func _ready() -> void:
	modulate = Color(modulate.r, modulate.g, modulate.b, 0.0)
	visible = debug_draw


func _process(_delta: float) -> void:
	if debug_draw:
		queue_redraw()

	var view_rect := _expanded_visible_rect_canvas()
	var inside := view_rect.intersects(_self_canvas_aabb())

	if inside and not _was_inside:
		_fade_in()
	elif not inside and _was_inside:
		_hide()
	_was_inside = inside

	if debug_draw and not inside:
		visible = true


func _draw() -> void:
	if not debug_draw:
		return
	var inv := get_global_transform_with_canvas().affine_inverse()
	_draw_canvas_rect_outline(inv, _self_canvas_aabb(), debug_chunk_color)
	_draw_canvas_rect_outline(inv, _expanded_visible_rect_canvas(), debug_view_color)


func _fade_in() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null

	_reset_children_modulate_white()
	visible = true
	var r := modulate.r
	var g := modulate.g
	var b := modulate.b
	modulate = Color(r, g, b, 0.0)
	_tween = create_tween()
	_tween.tween_property(
		self,
		"modulate",
		Color(r, g, b, 1.0),
		fade_duration
	).from(Color(r, g, b, 0.0))


func _hide() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	var r := modulate.r
	var g := modulate.g
	var b := modulate.b
	if debug_draw:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		_set_children_canvas_modulate(Color(r, g, b, 0.0))
	else:
		modulate = Color(r, g, b, 0.0)
		_reset_children_modulate_white()
	visible = debug_draw


func _reset_children_modulate_white() -> void:
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = Color.WHITE


func _set_children_canvas_modulate(col: Color) -> void:
	for child in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate = col


func _draw_canvas_rect_outline(inv: Transform2D, canvas_rect: Rect2, color: Color) -> void:
	var p0: Vector2 = inv * canvas_rect.position
	var p1: Vector2 = inv * (canvas_rect.position + Vector2(canvas_rect.size.x, 0.0))
	var p2: Vector2 = inv * canvas_rect.end
	var p3: Vector2 = inv * (canvas_rect.position + Vector2(0.0, canvas_rect.size.y))
	var w := debug_line_width
	draw_line(p0, p1, color, w)
	draw_line(p1, p2, color, w)
	draw_line(p2, p3, color, w)
	draw_line(p3, p0, color, w)


func _expanded_visible_rect_canvas() -> Rect2:
	# Chunk corners from get_global_transform_with_canvas() live in the viewport's coordinate
	# system (see CanvasItem.get_global_transform_with_canvas). Match that with get_viewport_rect(),
	# not get_visible_rect() (screen space) nor canvas_transform hacks.
	var base := get_viewport_rect()
	var margin_world := float(margin_tiles * TerrainChunkCodec.TILE_SIZE_PX)
	var cam := get_viewport().get_camera_2d()
	var z: float = cam.zoom.x if cam != null else 1.0
	var margin_vp := margin_world * z
	return Rect2(
		base.position - Vector2(margin_vp, margin_vp),
		base.size + Vector2(2.0 * margin_vp, 2.0 * margin_vp)
	)


func _self_canvas_aabb() -> Rect2:
	var xf := get_global_transform_with_canvas()
	var w := float(TerrainChunkCodec.CHUNK_SIZE * TerrainChunkCodec.TILE_SIZE_PX)
	var h := w
	var p0: Vector2 = xf * Vector2.ZERO
	var p1: Vector2 = xf * Vector2(w, 0.0)
	var p2: Vector2 = xf * Vector2(0.0, h)
	var p3: Vector2 = xf * Vector2(w, h)
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x))
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
