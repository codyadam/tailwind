extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.ctrl_pressed:
		match event.keycode:
			KEY_1:
				get_tree().change_scene_to_file("res://scenes/worlds/main_scene.tscn")
			KEY_2:
				get_tree().change_scene_to_file("res://scenes/worlds/tests_scene.tscn")