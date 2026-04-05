extends Camera2D

## Pans while game_secondary is held. Uses viewport mouse position instead of _unhandled_input
## so fullscreen Controls / GUI do not swallow InputEventMouseMotion.

@export var zoom_min: float = 0.25
@export var zoom_max: float = 4.0
@export var zoom_step: float = 1.1

var _prev_mouse_viewport: Vector2 = Vector2.ZERO

func _ready() -> void:
	_prev_mouse_viewport = get_viewport().get_mouse_position()

func _process(_delta: float) -> void:
	if GlobalState.game_input_locked:
		_prev_mouse_viewport = get_viewport().get_mouse_position()
		return
	if Input.is_action_just_pressed("game_zoom_in"):
		_apply_zoom(zoom_step)
	if Input.is_action_just_pressed("game_zoom_out"):
		_apply_zoom(1.0 / zoom_step)

	var mouse_vp := get_viewport().get_mouse_position()
	if Input.is_action_pressed("game_secondary") or Input.is_action_pressed("game_primary"):
		var rel := mouse_vp - _prev_mouse_viewport
		if rel != Vector2.ZERO:
			global_position -= rel / zoom
	_prev_mouse_viewport = mouse_vp

func _apply_zoom(factor: float) -> void:
	var z := clampf(zoom.x * factor, zoom_min, zoom_max)
	zoom = Vector2(z, z)
