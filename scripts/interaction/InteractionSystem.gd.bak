extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func raycast(
	camera: Camera3D,
	mouse_pos: Vector2,
	ray_length: float,
	exclude: Array[RID] = []
) -> Dictionary:

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_direction * ray_length

	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end
	)

	query.exclude = exclude

	var result = (
		camera
		.get_world_3d()
		.direct_space_state
		.intersect_ray(query)
	)

	return result

func interact(target):
	if target == null:
		return
	if target.has_method("interact"):
		target.interact()
