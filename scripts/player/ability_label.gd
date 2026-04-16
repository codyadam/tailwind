extends Label

@export var ability_manager: Node2D
@onready var _owning_player: Player = get_parent()

func _ready() -> void:
	if ability_manager == null:
		return
	Events.after_ability_switched.connect(_after_ability_switched)
	_after_ability_switched(ability_manager.current_ability, _owning_player)

func _after_ability_switched(ability: Ability, player: Player) -> void:
	if player != _owning_player:
		return
	if ability == null:
		text = ""
	else:
		text = ability.label
