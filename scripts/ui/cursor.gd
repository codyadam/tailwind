extends Node

## Central game cursors (replaces relying on per-ability loads and project display settings).
enum Kind { DEFAULT, BUILD, HOOK }

const HOTSPOT_DEFAULT := Vector2(10, 8)
const HOTSPOT_BUILD := Vector2(10, 10)
const HOTSPOT_HOOK := Vector2(16, 16)

const TEX_DEFAULT: Texture2D = preload("res://assets/cursors/Outline/pointer_b.svg")
const TEX_BUILD: Texture2D = preload("res://assets/cursors/Outline/tool_hammer.svg")
const TEX_HOOK: Texture2D = preload("res://assets/cursors/Outline/line_cross.svg")

var current: Kind = Kind.DEFAULT

func _ready() -> void:
	apply(Kind.DEFAULT)

func apply(kind: Kind) -> void:
	if current == kind:
		return
	current = kind
	match kind:
		Kind.DEFAULT:
			Input.set_custom_mouse_cursor(TEX_DEFAULT, Input.CURSOR_ARROW, HOTSPOT_DEFAULT)
		Kind.BUILD:
			Input.set_custom_mouse_cursor(TEX_BUILD, Input.CURSOR_ARROW, HOTSPOT_BUILD)
		Kind.HOOK:
			Input.set_custom_mouse_cursor(TEX_HOOK, Input.CURSOR_ARROW, HOTSPOT_HOOK)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func reset() -> void:
	apply(Kind.DEFAULT)