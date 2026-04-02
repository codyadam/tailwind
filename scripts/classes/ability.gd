@abstract
class_name Ability
extends Node2D

var is_active := false
var owner_player: Player = null

func setup(player: Player) -> void:
    owner_player = player

func activate() -> void:
    if is_active:
        return
    is_active = true
    set_process(true)
    set_physics_process(true)
    set_process_input(true)
    on_activate()
    visible = true

func deactivate() -> void:
    if not is_active:
        return
    on_deactivate()
    is_active = false
    set_process(false)
    set_physics_process(false)
    set_process_input(false)
    visible = false


func on_activate() -> void:
    pass

func on_deactivate() -> void:
    pass

func _ready() -> void:
    set_process(false)
    set_physics_process(false)
    set_process_input(false)
    visible = false