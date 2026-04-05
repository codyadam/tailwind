extends Node

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		Engine.max_fps = 0 #Zero means uncapped
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Engine.max_fps = 120