extends Node2D

@onready var label: Label = $CanvasLayer/Control/Label
@onready var blur_shader: ColorRect = $Camera2D/BlurShader
@onready var blur_shader2: ColorRect = $Camera2D/BlurShader2
@onready var voronoi_shader: ColorRect = $Camera2D/VoronoiShader
@onready var kuwahara_shader: ColorRect = $Camera2D/KuwaharaShader
@onready var kuwahara_shader2: ColorRect = $Camera2D/KuwaharaShader2

const DEFAULT_TEXT = "Left or right click + move to pan the camera

Toggle shaders using keyboard keys:"

var states = {
	"blur": false,
	"blur2": false,
	"voronoi": false,
	"kuwahara": true,
	"kuwahara2": false,
}

func _ready() -> void:
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				states["blur"] = !states["blur"]
			KEY_2:
				states["blur2"] = !states["blur2"]
			KEY_3:
				states["voronoi"] = !states["voronoi"]
			KEY_4:
				states["kuwahara"] = !states["kuwahara"]
			KEY_5:
				states["kuwahara2"] = !states["kuwahara2"]
		_update_ui()

func _update_ui() -> void:
	blur_shader.visible = states["blur"]
	voronoi_shader.visible = states["voronoi"]
	kuwahara_shader.visible = states["kuwahara"]
	blur_shader2.visible = states["blur2"]
	kuwahara_shader2.visible = states["kuwahara2"]
	label.text = DEFAULT_TEXT
	label.text += "\n1 - Blur: " + ("🟢 On" if states["blur"] else "🔴 Off")
	label.text += "\n2 - BlurShader2: " + ("🟢 On" if states["blur2"] else "🔴 Off")
	label.text += "\n3 - Voronoi: " + ("🟢 On" if states["voronoi"] else "🔴 Off")
	label.text += "\n4 - Kuwahara: " + ("🟢 On" if states["kuwahara"] else "🔴 Off")
	label.text += "\n5 - KuwaharaShader2: " + ("🟢 On" if states["kuwahara2"] else "🔴 Off")
