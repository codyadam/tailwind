extends Node2D

var fluid_sim: SubViewportContainer
@onready var remote_transform: RemoteTransform2D = $RemoteTransform2D

@export var sprite_texture: Texture2D
@export var sprite_scale: Vector2 = Vector2(5.0, 5.0)

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
	sprite.offset = -fluid_sim.global_position * 1/remote_transform.global_scale
	fluid_sim.get_node("SubViewport").add_child(sprite)
	remote_transform.remote_path = remote_transform.get_path_to(sprite)

func _exit_tree() -> void:
	if remote_transform and is_instance_valid(remote_transform):
		remote_transform.remote_path = NodePath()

	if sprite and is_instance_valid(sprite):
		sprite.queue_free()
	sprite = null
