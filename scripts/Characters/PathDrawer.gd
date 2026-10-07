extends Node3D
class_name PathDrawer

var path_mesh: MeshInstance3D
var immediate_mesh := ImmediateMesh.new()
var path_material := StandardMaterial3D.new()

func setup(parent: Node):
	path_mesh = MeshInstance3D.new()
	parent.add_child(path_mesh)
	path_mesh.top_level = true
	path_mesh.mesh = immediate_mesh
	path_mesh.set_layer_mask_value(1, false)
	path_mesh.set_layer_mask_value(18, true)

	path_material.albedo_color = Color(1.0, 1.0, 0.0, 0.765)
	path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_material.no_depth_test = false

func clear():
	immediate_mesh.clear_surfaces()

func update_path_display(node_owner: Node3D, agent: NavigationAgent3D):
	clear()
	
	var path = agent.get_current_navigation_path()
	if path.size() < 2:
		return

	var closest_index = 0
	var closest_dist = INF
	var closest_t = 0.0

	for i in range(path.size() - 1):
		var flat_player = Vector2(node_owner.global_position.x, node_owner.global_position.z)
		var flat_a = Vector2(path[i].x, path[i].z)
		var flat_b = Vector2(path[i + 1].x, path[i + 1].z)
		var seg_dir = flat_b - flat_a

		if seg_dir.length_squared() <= 0.001:
			continue

		var t = clamp((flat_player - flat_a).dot(seg_dir) / seg_dir.length_squared(), 0.0, 1.0)
		var closest_on_seg = flat_a + seg_dir * t
		var dist = flat_player.distance_to(closest_on_seg)

		if dist < closest_dist:
			closest_dist = dist
			closest_index = i
			closest_t = t

	var trimmed = PackedVector3Array()
	var y_start = lerp(path[closest_index].y, path[closest_index + 1].y, closest_t)
	trimmed.append(Vector3(node_owner.global_position.x, y_start, node_owner.global_position.z))

	for i in range(closest_index + 1, path.size()):
		trimmed.append(path[i])

	draw_path(node_owner, trimmed, 0.05)

func draw_path(node_owner: Node3D, points: PackedVector3Array, width: float = 0.2):
	immediate_mesh.clear_surfaces()

	if points.size() < 2:
		return

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, path_material)

	for i in range(points.size() - 1):
		var p1 = Vector3(points[i].x, get_surface_y(node_owner, points[i]), points[i].z)
		var p2 = Vector3(points[i + 1].x, get_surface_y(node_owner, points[i + 1]), points[i + 1].z)
		var dir = (p2 - p1).normalized()
		var perp = dir.cross(Vector3.UP).normalized() * (width * 0.5)

		immediate_mesh.surface_add_vertex(p1 + perp)
		immediate_mesh.surface_add_vertex(p1 - perp)

		if i == points.size() - 2:
			immediate_mesh.surface_add_vertex(p2 + perp)
			immediate_mesh.surface_add_vertex(p2 - perp)

	immediate_mesh.surface_end()

	var end_point = Vector3(points[-1].x, get_surface_y(node_owner, points[-1]), points[-1].z)
	var radius = 0.3

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, path_material)

	for i in range(33):
		var angle = (float(i) / 32.0) * TAU
		immediate_mesh.surface_add_vertex(
			end_point + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		)

	immediate_mesh.surface_end()

func get_surface_y(node_owner: Node3D, point: Vector3) -> float:
	var space_state = node_owner.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		point + Vector3(0, 1.0, 0),
		point + Vector3(0, -5.0, 0)
	)

	if node_owner is CollisionObject3D:
		query.exclude = [node_owner.get_rid()]

	var result = space_state.intersect_ray(query)

	if result:
		return result.position.y + 0.02

	return point.y
