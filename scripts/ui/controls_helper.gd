extends Label


@onready var default_text: String = text

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Events.after_ability_switched.connect(_after_ability_switched)

func _after_ability_switched(ability: Ability, player: Player) -> void:
	if not player or not player._is_controlling_locally():
		return
	if ability == null:
		text = default_text
	else:
		text = default_text + "\n\n" + ability.name + ":\n" + ability.controls_helper_text