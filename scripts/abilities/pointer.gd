extends Ability

@export var velocity_damping: float = 0.9
@export var rotation_multiplier: Vector2 = Vector2(10, 5)

@onready var pointer_sprite: Sprite2D = $Sprite

var textures: Array[Texture2D] = [
	preload("res://assets/cursors/Outline/hand_open.svg"),
	preload("res://assets/cursors/Outline/hand_point.svg"),
	preload("res://assets/cursors/Outline/busy_hourglass_outline_detail.svg"),
	preload("res://assets/cursors/Outline/cross_large.svg"),
	preload("res://assets/cursors/Outline/look_a.svg"),
	preload("res://assets/cursors/Outline/mark_exclamation.svg"),
	preload("res://assets/cursors/Outline/message_dots_round.svg"),
	preload("res://assets/cursors/Outline/steps.svg"),
	preload("res://assets/cursors/Outline/target_a.svg"),
	preload("res://assets/cursors/Outline/target_round_a.svg"),
	preload("res://assets/cursors/Outline/tool_axe.svg"),
	preload("res://assets/cursors/Outline/tool_bomb.svg"),
	preload("res://assets/cursors/Outline/tool_bow.svg"),
	preload("res://assets/cursors/Outline/tool_hammer.svg"),
	preload("res://assets/cursors/Outline/tool_hoe.svg"),
	preload("res://assets/cursors/Outline/tool_pickaxe.svg"),
	preload("res://assets/cursors/Outline/tool_shovel.svg"),
	preload("res://assets/cursors/Outline/tool_sword_a.svg"),
	preload("res://assets/cursors/Outline/tool_sword_b.svg"),
	preload("res://assets/cursors/Outline/tool_torch.svg"),
	preload("res://assets/cursors/Outline/tool_wand.svg"),
	preload("res://assets/cursors/Outline/tool_watering_can.svg"),
	preload("res://assets/cursors/Outline/tool_wrench.svg"),
]

var label: String = "☝️"
var controls_helper_text: String = "Scroll Up/Down — change pointer"

var velocity: Vector2 = Vector2.ZERO
var color: Color = Color.WHITE
var texture_index: int = 0

func setup(player: Player) -> void:
	super.setup(player)
	assert(pointer_sprite, "Pointer sprite not found")
	# generate a random color based on player name

	var hue := float((player.name.hash() % 360)) / 360.0
	var sat := 0.5
	var val := 0.95
	color = Color.from_hsv(hue, sat, val)
	pointer_sprite.visible = false
	pointer_sprite.texture = textures[texture_index]
	pointer_sprite.modulate = color

func on_activate() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	pointer_sprite.visible = true

func on_deactivate() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	velocity = Vector2.ZERO
	pointer_sprite.visible = false
	pointer_sprite.rotation = 0.0
	pointer_sprite.position = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_texture.rpc((texture_index - 1) % textures.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_texture.rpc((texture_index + 1) % textures.size())

func _process(delta: float) -> void:
	if not is_active:
		return
	if owner_player._is_controlling_locally():
		var new_position = to_local(get_global_mouse_position())
		var damp := pow(velocity_damping, delta * 60.0)
		velocity = (pointer_sprite.position - new_position) * (1 - damp) + velocity * damp
		pointer_sprite.rotation = velocity.x * rotation_multiplier.x / 100 + velocity.y * rotation_multiplier.y / 100
		pointer_sprite.position = new_position


@rpc("any_peer", "call_local", "unreliable")
func _change_texture(index: int) -> void:
	texture_index = index
	pointer_sprite.texture = textures[texture_index]
