class_name Player
extends CharacterBody2D

## Celeste-like momentum, jump assists, dash + post-dash drag.
## Ground vs wall vs ceiling uses CharacterBody2D collision flags from the last move_and_slide()
## (is_on_floor, is_on_wall, is_on_ceiling), with up_direction and floor_max_angle defining "floor".
## Client-authoritative: owning peer simulates; global_position and velocity replicate via MultiplayerSynchronizer (server_relay).

enum MoveState { RUN, DASH, POST_DASH }

@export_group("Run")
@export var max_run_speed: float = 260.0
@export var ground_accel: float = 2200.0
## Horizontal deceleration when grounded and not pressing left/right (not used on Y; gravity handles vertical).
@export var ground_friction: float = 2800.0
@export var air_accel: float = 2200.0
## Deceleration in air (perpendicular to gravity) when not pressing left/right.
@export var air_friction: float = 520.0

@export_group("Horizontal strafe")
## When input opposes current horizontal motion (e.g. sliding left, press right). Scales ground and air accel.
@export_range(0.5, 10.0) var strafe_opposing_multiplier: float = 2.2
## When already moving with the input; gentle ramp toward max run speed. Scales ground and air accel.
@export_range(0.1, 1.0) var strafe_aligned_multiplier: float = 0.5
## Below this |horizontal speed| (px/s), use baseline accel (multiplier 1). Avoids sluggish starts from rest.
@export_range(0.0, 300.0) var strafe_neutral_deadzone: float = 12.0

@export_group("Jump")
@export var jump_velocity: float = -420.0
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
## Grace period after leaving the ground where a jump still counts as grounded.
@export var coyote_time: float = 0.12
## Time window to press jump before landing; jump triggers on the next grounded frame.
@export var jump_buffer_time: float = 0.12
@export_range(0.5, 3.0) var fall_gravity_multiplier: float = 1.35
## Extra multiplier on gravity while holding `game_down` in the air (fast fall).
@export_range(1.0, 5.0) var down_input_gravity_multiplier: float = 1.5

@export_group("Dash")
@export var dash_speed: float = 520.0
@export var dash_duration: float = 0.17
@export_range(0.0, 1.0) var dash_gravity_scale: float = 0.0
## If the cursor is within this radius of the player (world units), dash uses facing instead.
@export var dash_mouse_deadzone: float = 8.0

@export_group("Visual (dash)")
@export var dash_ready_modulate: Color = Color.WHITE
@export var dash_spent_modulate: Color = Color(0.65, 0.65, 0.8, 1.0)

@export_group("Visual (fast fall)")
## Horizontal scale multiplier while holding down in the air (below 1 = narrower squish).
@export_range(0.3, 1.0) var fast_fall_squish_x: float = 0.7
## Slight vertical stretch to pair with horizontal squish; set to 1.0 for X-only.
@export_range(1.0, 1.5) var fast_fall_stretch_y: float = 1.2
## How quickly the sprite reaches the squished/rest pose (higher = snappier).
@export var fast_fall_squish_lerp: float = 5.0

@export_group("Post-dash")
@export var post_dash_duration: float = 0.32
@export var post_dash_air_drag: float = 600.0
@export var post_dash_ground_drag: float = 3200.0

var _state: MoveState = MoveState.RUN
var _dash_available: bool = true
var _dash_timer: float = 0.0
var _post_dash_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _was_on_wall: bool = false
var _facing_x: float = 1.0

@onready var _sprite: Sprite2D = $Sprite2D

var _sprite_base_scale: Vector2 = Vector2.ONE
var _has_sync_occurred: bool = false

func _enter_tree() -> void:
	if not _is_controlling_locally():
		$CollisionShape2D.disabled = true
		visible = false

func _ready() -> void:
	_refresh_camera_remote_transforms()
	if _sprite:
		_sprite_base_scale = _sprite.scale
	if not _is_controlling_locally():
		$MultiplayerSynchronizer.synchronized.connect(_on_synchronized)

func _on_synchronized() -> void:
	# trick to avoid collision with other players while they are not yet synchronized
	if _has_sync_occurred:
		return
	$CollisionShape2D.disabled = false
	visible = true
	_has_sync_occurred = true

func _is_controlling_locally() -> bool:
	return multiplayer.get_unique_id() == get_multiplayer_authority()


func _refresh_camera_remote_transforms() -> void:
	var mct := $MainCamTransform as RemoteTransform2D
	var oct := $OtherCamTransform as RemoteTransform2D
	var follow := _is_controlling_locally()
	if follow:
		# Player lives under Main Scene / Network / Player — three parents up to scene root where MainCam and VP0 live.
		mct.remote_path = NodePath("../../../MainCam")
		oct.remote_path = NodePath("../../../Minimap/MinimapCam")
	else:
		mct.remote_path = NodePath("")
		oct.remote_path = NodePath("")


func _do_reset() -> void:
	global_position = Vector2.ZERO
	velocity = Vector2.ZERO
	_state = MoveState.RUN
	_dash_available = true
	_dash_timer = 0.0
	_post_dash_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


# Order: timers from last slide -> state velocity -> move_and_slide -> wall dash/coyote (is_on_wall / is_on_floor per last move_and_slide)
func _physics_process(delta: float) -> void:
	if not _is_controlling_locally():
		return

	if Input.is_action_just_pressed("game_reset"):
		_do_reset()

	var on_floor := is_on_floor()
	var gravity := get_gravity()

	_handle_floor_enter(on_floor)
	_was_on_floor = on_floor

	_update_coyote(delta, on_floor)
	_update_jump_buffer(delta)

	var axis_x := Input.get_axis("game_left", "game_right")
	if axis_x != 0.0:
		_facing_x = signf(axis_x)

	match _state:
		MoveState.RUN:
			_run_physics(delta, gravity, on_floor, axis_x)
		MoveState.DASH:
			_dash_physics(delta, gravity)
		MoveState.POST_DASH:
			_post_dash_physics(delta, gravity, on_floor, axis_x)

	move_and_slide()

	var on_wall := is_on_wall()
	if on_wall:
		_handle_wall_contact()
		_try_consume_jump(is_on_floor(), true)
	_was_on_wall = on_wall

	_update_dash_visual()
	_update_fast_fall_squish(delta, is_on_floor())


func _update_fast_fall_squish(delta: float, on_floor: bool) -> void:
	if not _sprite:
		return
	var x_mult := fast_fall_squish_x if (not on_floor and Input.is_action_pressed("game_down")) else 1.0
	var y_mult := fast_fall_stretch_y if (not on_floor and Input.is_action_pressed("game_down")) else 1.0
	var target := Vector2(_sprite_base_scale.x * x_mult, _sprite_base_scale.y * y_mult)
	var step := fast_fall_squish_lerp * maxf(absf(_sprite_base_scale.x), absf(_sprite_base_scale.y)) * delta
	_sprite.scale = _sprite.scale.move_toward(target, step)


func _update_dash_visual() -> void:
	if _sprite:
		_sprite.modulate = dash_ready_modulate if _dash_available else dash_spent_modulate


func _handle_floor_enter(on_floor: bool) -> void:
	if on_floor and not _was_on_floor:
		_dash_available = true


func _handle_wall_contact() -> void:
	_dash_available = true
	_coyote_timer = coyote_time


func _update_coyote(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = coyote_time
	elif _was_on_wall:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func _update_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed("game_jump"):
		_jump_buffer_timer = jump_buffer_time
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _gravity_unit(gravity: Vector2) -> Vector2:
	if gravity.length_squared() < 0.0001:
		return Vector2.DOWN
	return gravity.normalized()


## Tangent for run/air strafe: +X when gravity points down (default).
func _air_tangent(g_hat: Vector2) -> Vector2:
	return Vector2(g_hat.y, -g_hat.x)


## Opposing vs aligned horizontal accel; `signed_horizontal_speed` is velocity along strafe axis (ground: x, air: tangent scalar).
func _strafe_accel_multiplier(axis_x: float, signed_horizontal_speed: float) -> float:
	if axis_x == 0.0:
		return strafe_opposing_multiplier
	if absf(signed_horizontal_speed) < strafe_neutral_deadzone:
		return strafe_opposing_multiplier
	if signf(signed_horizontal_speed) != 0.0 and signf(axis_x) != signf(signed_horizontal_speed):
		return strafe_opposing_multiplier
	return strafe_aligned_multiplier


func _apply_air_plane_velocity(
	v: Vector2,
	gravity: Vector2,
	axis_x: float,
	delta: float,
	accel: float,
	friction: float,
	max_speed: float
) -> Vector2:
	var g_hat := _gravity_unit(gravity)
	var v_parallel := g_hat * v.dot(g_hat)
	var v_perp := v - v_parallel
	var tangent := _air_tangent(g_hat)
	# Scalar speed along tangent (signed). Targeting only max_speed makes move_toward brake
	# anything faster — bad right after a dash. When input matches movement, keep current speed.
	var s_perp := v_perp.dot(tangent)
	var target_scalar := axis_x * max_speed
	if axis_x != 0.0 and signf(s_perp) == axis_x:
		target_scalar = axis_x * maxf(max_speed, absf(s_perp))
	var target_perp := tangent * target_scalar
	if axis_x != 0.0:
		var m := _strafe_accel_multiplier(axis_x, s_perp)
		v_perp = v_perp.move_toward(target_perp, accel * m * delta)
	else:
		v_perp = v_perp.move_toward(Vector2.ZERO, friction * delta)
	return v_parallel + v_perp


func _apply_gravity(delta: float, gravity: Vector2, on_floor: bool) -> void:
	if on_floor:
		return
	var g_hat := _gravity_unit(gravity)
	var gmult := fall_gravity_multiplier if velocity.dot(g_hat) > 0.0 else 1.0
	if Input.is_action_pressed("game_down"):
		gmult *= down_input_gravity_multiplier
	velocity += gravity * gmult * delta


func _try_consume_jump(on_floor: bool, on_wall: bool = false) -> void:
	var can_jump := on_floor or _coyote_timer > 0.0 or on_wall
	if _jump_buffer_timer > 0.0 and can_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _apply_jump_cut() -> void:
	if Input.is_action_just_released("game_jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _run_physics(delta: float, gravity: Vector2, on_floor: bool, axis_x: float) -> void:
	if Input.is_action_just_pressed("game_dash") and _dash_available:
		_start_dash()
		return

	_apply_gravity(delta, gravity, on_floor)
	_try_consume_jump(on_floor, _was_on_wall)
	_apply_jump_cut()

	if on_floor:
		var target_x := axis_x * max_run_speed
		if axis_x != 0.0:
			var gm := _strafe_accel_multiplier(axis_x, velocity.x)
			velocity.x = move_toward(velocity.x, target_x, ground_accel * gm * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		# Do not zero Y after jump: upward velocity is negative; only shed downward into floor.
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity = _apply_air_plane_velocity(velocity, gravity, axis_x, delta, air_accel, air_friction, max_run_speed)


func _start_dash() -> void:
	_dash_available = false
	_state = MoveState.DASH
	_dash_timer = dash_duration

	var dir := _get_dash_direction()
	if dir == Vector2.ZERO:
		dir = Vector2(_facing_x, 0.0)
	else:
		dir = dir.normalized()
		if dir.x != 0.0:
			_facing_x = signf(dir.x)

	velocity = dir * dash_speed


func _get_dash_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	var deadzone_sq := dash_mouse_deadzone * dash_mouse_deadzone
	if to_mouse.length_squared() < deadzone_sq:
		return Vector2.ZERO
	return to_mouse


func _dash_physics(delta: float, gravity: Vector2) -> void:
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_state = MoveState.POST_DASH
		_post_dash_timer = post_dash_duration
		return

	var dash_dir := velocity
	if dash_dir.length_squared() < 0.01:
		dash_dir = Vector2(_facing_x, 0.0)
	else:
		dash_dir = dash_dir.normalized()
	velocity = dash_dir * dash_speed

	if dash_gravity_scale > 0.0 and not is_on_floor():
		velocity += gravity * dash_gravity_scale * delta


func _post_dash_physics(delta: float, gravity: Vector2, on_floor: bool, axis_x: float) -> void:
	_post_dash_timer -= delta
	if _post_dash_timer <= 0.0:
		_end_post_dash()

	_apply_gravity(delta, gravity, on_floor)
	_try_consume_jump(on_floor, _was_on_wall)
	_apply_jump_cut()

	if Input.is_action_just_pressed("game_dash") and _dash_available:
		_start_dash()
		return

	var target_x := axis_x * max_run_speed
	if on_floor:
		var drag := post_dash_ground_drag
		if axis_x != 0.0:
			var gm := _strafe_accel_multiplier(axis_x, velocity.x)
			velocity.x = move_toward(velocity.x, target_x, ground_accel * gm * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, drag * delta)
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity = _apply_air_plane_velocity(
			velocity,
			gravity,
			axis_x,
			delta,
			air_accel,
			post_dash_air_drag,
			max_run_speed
		)


func _end_post_dash() -> void:
	_state = MoveState.RUN
	_post_dash_timer = 0.0
