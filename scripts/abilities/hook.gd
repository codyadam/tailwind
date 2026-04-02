extends Ability

@export var stiffness: float = 48.0
@export var damping: float = 14.0
@export var rest_length: float = 40.0

@onready var tip: Sprite2D = $Tip
@onready var line: Line2D = $Line
@onready var ray: RayCast2D = $RayCast2D
@onready var max_range: float = ray.target_position.length()
@onready var hint: Sprite2D = $Hint

var label: String = "🪝"
var controls_helper_text: String = "Right Click - Hook"

var launched: bool = false
var _target: Vector2 = Vector2.ZERO


func setup(player: Player) -> void:
	super.setup(player)
	if ray and owner_player:
		ray.clear_exceptions()
		ray.add_exception(owner_player)

	if owner_player._is_controlling_locally():
		hint.visible = true
	else:
		hint.visible = false


func on_activate() -> void:
	retract()
	ray.enabled = true



func on_deactivate() -> void:
	retract()
	ray.enabled = false

func _process(_delta: float) -> void:
	line.set_point_position(1, tip.position)


func _physics_process(delta: float) -> void:
	if not owner_player or not owner_player._is_controlling_locally():
		return

	ray.look_at(get_global_mouse_position())
	ray.target_position = Vector2(max_range, 0.0)

	if Input.is_action_just_pressed("game_secondary"):
		launch()
	if Input.is_action_just_released("game_secondary"):
		retract()

	if launched:
		handle_grapple(delta)


func launch() -> void:
	ray.force_raycast_update()
	if ray.is_colliding():
		launched = true
		_target = ray.get_collision_point()


func retract() -> void:
	launched = false
	_target = Vector2.ZERO
	tip.position = Vector2.ZERO
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func handle_grapple(delta: float) -> void:
	var target_dir := owner_player.global_position.direction_to(_target)
	var target_dist := owner_player.global_position.distance_to(_target)
	var displacement := target_dist - rest_length

	var force := Vector2.ZERO
	if displacement > 0.0:
		var spring_force := target_dir * (stiffness * displacement)
		var vel_dot := owner_player.velocity.dot(target_dir)
		var damp_force := -damping * vel_dot * target_dir
		force = spring_force + damp_force

	owner_player.velocity += force * delta
	tip.position = to_local(_target)
