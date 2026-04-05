extends Ability

@export var stiffness: float = 48.0
@export var damping: float = 14.0
@export var rest_length: float = 40.0

@onready var tip: Sprite2D = $Tip
@onready var line: Line2D = $Line
@onready var ray: RayCast2D = $RayCast2D
@onready var max_range: float = ray.target_position.length()
@onready var range_hint: Sprite2D = $RangeHint
@onready var target_hint: Sprite2D = $TargetHint

var label: String = "🪝"
var controls_helper_text: String = "Right Click — hook walls or players (pulls them to you)"

var launched: bool = false
var _target: Vector2 = Vector2.ZERO
var _hooked_player: Player = null


func setup(player: Player) -> void:
	super.setup(player)
	if ray and owner_player:
		ray.clear_exceptions()
		ray.add_exception(owner_player)

	target_hint.visible = false
	if owner_player._is_controlling_locally():
		range_hint.visible = true
	else:
		range_hint.visible = false


func on_activate() -> void:
	retract()
	ray.enabled = true
	if owner_player._is_controlling_locally():
		Cursor.apply(Cursor.Kind.HOOK)


func on_deactivate() -> void:
	retract()
	ray.enabled = false
	Cursor.reset()

func _process(_delta: float) -> void:
	if not is_active:
		return
	line.set_point_position(1, tip.position)
	if not owner_player._is_controlling_locally():
		return
	if not launched:
		# simulate the ray hitting the target to show the target hint
		ray.look_at(get_global_mouse_position())
		ray.force_raycast_update()
		if ray.is_colliding():
			target_hint.position = to_local(ray.get_collision_point())
			target_hint.visible = true
		else:
			target_hint.visible = false
	else:
		target_hint.visible = false


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	if not owner_player or not owner_player._is_controlling_locally():
		return

	ray.look_at(get_global_mouse_position())
	ray.target_position = Vector2(max_range, 0.0)

	if not GlobalState.game_input_locked:
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
		var collider := ray.get_collider()
		if collider is Player and collider != owner_player:
			_hooked_player = collider
			_target = collider.global_position
		else:
			_hooked_player = null
			_target = ray.get_collision_point()


func retract() -> void:
	launched = false
	_hooked_player = null
	_target = Vector2.ZERO
	tip.position = Vector2.ZERO
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func handle_grapple(delta: float) -> void:
	if _hooked_player != null and not is_instance_valid(_hooked_player):
		retract()
		return
	if _hooked_player != null:
		_target = _hooked_player.global_position
		var grabber_pos := owner_player.global_position
		var victim := _hooked_player
		var to_grabber := victim.global_position.direction_to(grabber_pos)
		var dist := victim.global_position.distance_to(grabber_pos)
		var overhang := dist - rest_length
		if overhang > 0.0:
			var spring_force := to_grabber * (stiffness * overhang)
			var vel_dot := victim.velocity.dot(to_grabber)
			var damp_force := -damping * vel_dot * to_grabber
			var impulse := (spring_force + damp_force) * delta
			var auth := victim.get_multiplayer_authority()
			if auth > 0 and auth != multiplayer.get_unique_id():
				victim.apply_hook_pull.rpc_id(auth, impulse, grabber_pos, max_range)
		tip.position = to_local(_target)
		return

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
