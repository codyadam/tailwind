extends Node2D

var fluid_sim: SubViewportContainer
@onready var remote_transform: RemoteTransform2D = $RemoteTransform2D

@export var sprite_texture: Texture2D
@export var sprite_scale: Vector2 = Vector2(5.0, 5.0)
## Below this speed (px/s), alpha is 0 and RGB stays neutral (fully faded out).
@export var min_speed_invisible: float = 8.0
## At and above this speed (px/s), alpha is 1 and direction RGB is full strength.
@export var max_speed_for_alpha: float = 400.0

var sprite: Sprite2D # will be created in _enter_tree


func _ready() -> void:
	fluid_sim = $"/root/Main/FluidSim"
	assert(fluid_sim != null, "FluidSim not found")
	assert(sprite_texture != null, "Sprite texture not set")

	# create a new sprite as child of the fluid_sim_viewport and attach the transform to it
	sprite = Sprite2D.new()
	sprite.name = "FluidActorSprite_%s" % get_parent().name
	remote_transform.global_scale = sprite_scale
	sprite.texture = sprite_texture
	sprite.modulate = Color(0.5, 0.5, 0.5, 0.0)
	sprite.offset = -fluid_sim.global_position * 1 / remote_transform.global_scale
	fluid_sim.get_node("SubViewport").add_child(sprite)
	remote_transform.remote_path = remote_transform.get_path_to(sprite)


func _physics_process(_delta: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var vel := _parent_velocity()
	var speed := vel.length()
	var mn := min_speed_invisible
	var mx := max_speed_for_alpha
	if mx <= mn + 0.001:
		mx = mn + 0.001
	var t := 0.0
	if speed >= mx:
		t = 1.0
	elif speed <= mn:
		t = 0.0
	else:
		t = (speed - mn) / (mx - mn)
	var dir := Vector2.ZERO
	if speed > 0.0001:
		dir = vel / speed
	# Lerp neutral (0.5,0.5) toward direction-encoded RG; alpha follows same t.
	var r := 0.5 - 0.5 * dir.x * t
	var g := 0.5 - 0.5 * dir.y * t
	sprite.modulate = Color(r, g, 0.5, t)


func _parent_velocity() -> Vector2:
	var p := get_parent()
	if p is CharacterBody2D:
		return (p as CharacterBody2D).velocity
	if p is RigidBody2D:
		return (p as RigidBody2D).linear_velocity
	return Vector2.ZERO


func _exit_tree() -> void:
	if remote_transform and is_instance_valid(remote_transform):
		remote_transform.remote_path = NodePath()

	if sprite and is_instance_valid(sprite):
		sprite.queue_free()
	sprite = null
