extends SubViewport

func _ready() -> void:
	var viewport = get_parent().get_viewport()
	world_2d = viewport.world_2d
