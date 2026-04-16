extends Node

@export var default_ability: Ability

var current_ability: Ability
@onready var player: Player = get_parent()


func _ready() -> void:
    for child in get_children():
        if child is Ability:
            child.setup(get_parent())

@rpc("any_peer", "call_local", "unreliable")
func switch_to_ability(ability_name: String) -> void:
    var next := get_node_or_null(ability_name) as Ability
    if next == current_ability:
        return
    if current_ability:
        current_ability.deactivate()

    current_ability = next
    if current_ability != null:
        current_ability.activate()
    elif player._is_controlling_locally():
        Cursor.apply(Cursor.Kind.DEFAULT)
    Events.after_ability_switched.emit(current_ability, player)
    if current_ability:
        print("Ability: ", current_ability.label, " ",current_ability.name)
    else:
        print("Ability: None")




func _unhandled_input(event: InputEvent) -> void:
    if not player or not player._is_controlling_locally():
        return
    if GlobalState.game_input_locked:
        return
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_1:
                switch_to_ability.rpc("Build")
            KEY_2:
                switch_to_ability.rpc("Hook")
            KEY_3:
                switch_to_ability.rpc("Pointer")
            KEY_4:
                switch_to_ability.rpc("")
            KEY_5:
                switch_to_ability.rpc("")
            KEY_6:
                switch_to_ability.rpc("")
            KEY_7:
                switch_to_ability.rpc("")
            KEY_8:
                switch_to_ability.rpc("")
            KEY_9:
                switch_to_ability.rpc("")