@tool
extends EditorScript

const POSITION_EPSILON := 0.0001
const SMOOTH_ANGLE_DEGREES := 70.0

func _run() -> void:
	print("Smooth: Starting...")

	var selected := EditorInterface.get_selection().get_selected_nodes()

	if selected.size() != 1 or not selected[0] is MeshInstance3D:
		push_error("Select one MeshInstance3D.")
		return

	var mesh_instance: MeshInstance3D = selected[0]
	var source := mesh_instance.mesh as ArrayMesh

	if source == null:
		push_error("Selected node has no ArrayMesh.")
		return

	if not source.resource_path.ends_with(".res"):
		push_error("Save the original mesh as a .res file first.")
		return

	if source.get_blend_shape_count() > 0:
		push_error("This version does not support blend shapes. Source was not modified.")
		return

	var output_path := source.resource_path.get_basename() + "_smooth.res"

	if FileAccess.file_exists(output_path):
		push_error("Output already exists: " + output_path)
		return

	var result := ArrayMesh.new()
	result.custom_aabb = source.custom_aabb

	var total_vertices := 0
	var total_triangles := 0
	var cosine_limit := cos(deg_to_rad(SMOOTH_ANGLE_DEGREES))

	for surface in range(source.get_surface_count()):
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			push_error("Surface %d is not a triangle surface." % surface)
			return

		var arrays := source.surface_get_arrays(surface).duplicate(true)

		if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			push_error("Surface %d has no vertex array." % surface)
			return

		if not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			push_error("Surface %d has no normal array." % surface)
			return

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var original_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var vertex_count := vertices.size()

		if vertex_count == 0 or original_normals.size() != vertex_count:
			push_error("Invalid vertex or normal count on surface %d." % surface)
			return

		var indices := PackedInt32Array()

		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]

		var indexed := not indices.is_empty()
		var element_count := indices.size() if indexed else vertex_count

		if element_count % 3 != 0:
			push_error("Triangle indices are incomplete.")
			return

		var triangle_count := element_count / 3

		# Preserve 4-bone / 8-bone skinning layout.
		var original_format := source.surface_get_format(surface)
		var skin_flags := original_format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		var bones_per_vertex := 8 if skin_flags != 0 else 4

		if arrays[Mesh.ARRAY_BONES] is PackedInt32Array:
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			if bones.size() != vertex_count * bones_per_vertex:
				push_error("Unexpected bone array size.")
				return

		if arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array:
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if weights.size() != vertex_count * bones_per_vertex:
				push_error("Unexpected weight array size.")
				return

		# Step 1: Calculate area-weighted face normals.
		var sums := PackedVector3Array()
		sums.resize(vertex_count)

		for t in range(triangle_count):
			var a: int
			var b: int
			var c: int

			if indexed:
				a = indices[t * 3]
				b = indices[t * 3 + 1]
				c = indices[t * 3 + 2]
			else:
				a = t * 3
				b = t * 3 + 1
				c = t * 3 + 2

			if a < 0 or b < 0 or c < 0:
				push_error("Negative vertex index.")
				return

			if a >= vertex_count or b >= vertex_count or c >= vertex_count:
				push_error("Vertex index out of range.")
				return

			var edge1 := vertices[b] - vertices[a]
			var edge2 := vertices[c] - vertices[a]
			var face_normal := edge2.cross(edge1)

			if face_normal.length_squared() < 0.000000000001:
				continue

			sums[a] += face_normal
			sums[b] += face_normal
			sums[c] += face_normal

		# Step 2: Group vertices sharing the same position.
		var groups := {}

		for i in range(vertex_count):
			var p := vertices[i]
			var key := Vector3i(
				roundi(p.x / POSITION_EPSILON),
				roundi(p.y / POSITION_EPSILON),
				roundi(p.z / POSITION_EPSILON)
			)

			if not groups.has(key):
				groups[key] = []

			groups[key].append(i)

		# Step 3: Smooth neighboring geometric normals.
		var new_normals := original_normals.duplicate()

		for group in groups.values():
			for vertex_index in group:
				var base_normal: Vector3 = sums[vertex_index]

				if base_normal.length_squared() < 0.000000000001:
					continue

				base_normal = base_normal.normalized()

				var total := Vector3.ZERO

				for neighbor in group:
					var candidate: Vector3 = sums[neighbor]

					if candidate.length_squared() < 0.000000000001:
						continue

					var candidate_normal := candidate.normalized()

					if base_normal.dot(candidate_normal) >= cosine_limit:
						total += candidate

				if total.length_squared() > 0.000000000001:
					new_normals[vertex_index] = total.normalized()
				else:
					new_normals[vertex_index] = base_normal

		# Only replace normals. Keep bone weights, UVs and indices.
		arrays[Mesh.ARRAY_NORMAL] = new_normals

		print(
			"Surface ", surface,
			": ", vertex_count, " vertices, ",
			triangle_count, " triangles."
		)

		# No imported LODs or incompatible format masks.
		result.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			arrays,
			[],
			{},
			skin_flags
		)

		if result.get_surface_count() != surface + 1:
			push_error("Failed to build surface %d." % surface)
			return

		result.surface_set_material(
			surface,
			source.surface_get_material(surface)
		)

		result.surface_set_name(
			surface,
			source.surface_get_name(surface)
		)

		total_vertices += vertex_count
		total_triangles += triangle_count

	var save_error := ResourceSaver.save(result, output_path)

	if save_error != OK:
		push_error("Save failed. Error code: %d" % save_error)
		return

	print("SUCCESS: ", output_path)
	print("Vertices: ", total_vertices)
	print("Triangles: ", total_triangles)
	print("Original mesh was not modified.")
