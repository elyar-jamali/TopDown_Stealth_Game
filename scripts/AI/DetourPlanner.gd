class_name DetourPlanner
extends RefCounted
const NAV_SAMPLE_STEP := 0.35
const NAV_SNAP_TOLERANCE := 0.60
const SHAPE_SHRINK := 0.06

static func get_blocking_collision_line(body: CharacterBody3D, collision_shape: CollisionShape3D) -> PackedVector3Array:
	var contacts: Dictionary = {}
	for i in range(body.get_slide_collision_count()):
		var collision := body.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null or not collider is CollisionObject3D:
			continue
		if abs(collision.get_normal().y) > 0.7:
			continue
		var collider_id := collider.get_instance_id()
		if not contacts.has(collider_id):
			var contact_position := collision.get_position()
			contact_position.y = body.global_position.y
			contacts[collider_id] = contact_position
	if contacts.size() < 2:
		var space_state := body.get_world_3d().direct_space_state
		var ray_origin: Vector3 = collision_shape.global_position
		var search_radius: float = maxf(_get_body_radius(collision_shape.shape) * 4.0, 1.5)
		var ray_count := 24
		for i in range(ray_count):
			var angle: float = TAU * float(i) / float(ray_count)
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var query := PhysicsRayQueryParameters3D.create(
				ray_origin,
				ray_origin + direction * search_radius
			)
			query.exclude = [body.get_rid()]
			query.collision_mask = body.collision_mask
			var hit := space_state.intersect_ray(query)
			if hit.is_empty():
				continue
			var collider: Object = hit.get("collider")
			if not collider is CollisionObject3D:
				continue
			var normal: Vector3 = hit["normal"]
			if abs(normal.y) > 0.7:
				continue
			var collider_id: int = collider.get_instance_id()
			if not contacts.has(collider_id):
				var contact_position: Vector3 = hit["position"]
				contact_position.y = body.global_position.y
				contacts[collider_id] = contact_position
		if contacts.size() < 2:
			return PackedVector3Array()
	var points: Array = contacts.values()
	var best_a := Vector3.ZERO
	var best_b := Vector3.ZERO
	var best_distance := 0.0
	for i in range(points.size()):
		for j in range(i + 1, points.size()):
			var distance := _horizontal_distance(points[i], points[j])
			if distance > best_distance:
				best_distance = distance
				best_a = points[i]
				best_b = points[j]
	return PackedVector3Array([best_a, best_b])

static func find_path(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	agent: NavigationAgent3D,
	final_target: Vector3,
	forward_direction: Vector3,
	blocking_line: PackedVector3Array = PackedVector3Array()
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var navigation_map := agent.get_navigation_map()
	if not navigation_map.is_valid():
		return result
	forward_direction.y = 0.0
	if forward_direction.length_squared() < 0.0001:
		return result
	forward_direction = forward_direction.normalized()
	var side_direction := Vector3(
		-forward_direction.z,
		0.0,
		forward_direction.x
	)
	var body_radius : float = _get_body_radius(collision_shape.shape)
	var base_clearance : float = max(body_radius * 2.0 + 0.25, 1.0)
	var lateral_distances := PackedFloat32Array([
		base_clearance,
		base_clearance * 1.5,
		base_clearance * 2.0,
		base_clearance * 2.75
	])
	var forward_distances := PackedFloat32Array([
		max(base_clearance * 1.5, 1.5),
		max(base_clearance * 2.5, 2.5),
		max(base_clearance * 3.5, 3.5),
		max(base_clearance * 5.0, 5.0)
	])
	var side_signs := PackedFloat32Array([-1.0, 1.0])
	var best_path: Array[Vector3] = []
	var best_cost : float = INF
	for side_sign in side_signs:
		for lateral_distance in lateral_distances:
			for forward_distance in forward_distances:
				var side_offset := side_direction * lateral_distance * side_sign
				var forward_offset := forward_direction * forward_distance
				var route_a: Array[Vector3] = [
					body.global_position + side_offset,
					body.global_position + side_offset + forward_offset,
					body.global_position + forward_offset
				]
				var route_b: Array[Vector3] = [
					body.global_position + side_offset + forward_direction * (base_clearance * 0.5),
					body.global_position + side_offset + forward_offset,
					body.global_position + forward_offset
				]
				var checked_a := _prepare_route(
					body,
					collision_shape,
					navigation_map,
					route_a,
					blocking_line
				)
				if not checked_a.is_empty():
					var cost_a : float = _route_cost(body.global_position, checked_a, final_target)
					if cost_a < best_cost:
						best_cost = cost_a
						best_path = checked_a
				var checked_b := _prepare_route(
					body,
					collision_shape,
					navigation_map,
					route_b,
					blocking_line
				)
				if not checked_b.is_empty():
					var cost_b : float = _route_cost(body.global_position, checked_b, final_target)
					if cost_b < best_cost:
						best_cost = cost_b
						best_path = checked_b
	if best_path.is_empty():
		return _find_backtrack_path(
			body,
			collision_shape,
			navigation_map,
			final_target,
			forward_direction,
			side_direction,
			base_clearance,
			blocking_line
		)
	return best_path

static func _find_backtrack_path(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	navigation_map: RID,
	final_target: Vector3,
	forward_direction: Vector3,
	side_direction: Vector3,
	base_clearance: float,
	blocking_line: PackedVector3Array
) -> Array[Vector3]:
	var start: Vector3 = body.global_position
	var back_distances := PackedFloat32Array([
		base_clearance * 0.75,
		base_clearance * 1.5,
		base_clearance * 2.5
	])
	var side_distances := PackedFloat32Array([
		base_clearance,
		base_clearance * 1.5,
		base_clearance * 2.5
	])
	var forward_distances := PackedFloat32Array([
		maxf(base_clearance * 2.5, 2.5),
		maxf(base_clearance * 4.0, 4.0),
		maxf(base_clearance * 6.0, 6.0)
	])
	var retreat_directions: Array[Vector3] = [
		-forward_direction
	]
	if blocking_line.size() >= 2:
		var line_direction: Vector3 = blocking_line[1] - blocking_line[0]
		line_direction.y = 0.0
		if line_direction.length_squared() > 0.0001:
			line_direction = line_direction.normalized()
			var perpendicular := Vector3(
				-line_direction.z,
				0.0,
				line_direction.x
			)
			if perpendicular.dot(-forward_direction) < 0.0:
				perpendicular = -perpendicular
			retreat_directions.append(perpendicular)
			retreat_directions.append(-perpendicular)
	var best_path: Array[Vector3] = []
	var best_cost := INF
	for retreat_index in range(retreat_directions.size()):
		var retreat_direction: Vector3 = retreat_directions[retreat_index]
		var lateral_direction: Vector3 = side_direction
		if retreat_index > 0:
			lateral_direction = Vector3(
				-retreat_direction.z,
				0.0,
				retreat_direction.x
			)
		for back_distance in back_distances:
			var back_point: Vector3 = start + retreat_direction * back_distance
			for side_sign in [-1.0, 1.0]:
				for side_distance in side_distances:
					var side_offset: Vector3 = lateral_direction * side_distance * float(side_sign)
					var side_point: Vector3 = back_point + side_offset
					for forward_distance in forward_distances:
						var forward_point: Vector3 = start + side_offset + forward_direction * forward_distance
						var merge_point: Vector3 = start + forward_direction * forward_distance
						var candidate: Array[Vector3] = [
							back_point,
							side_point,
							forward_point,
							merge_point
						]
						var checked := _prepare_route(
							body,
							collision_shape,
							navigation_map,
							candidate,
							blocking_line
						)
						if checked.is_empty():
							continue
						var cost: float = _route_cost(start, checked, final_target)
						if cost < best_cost:
							best_cost = cost
							best_path = checked
		if retreat_index == 0 and not best_path.is_empty():
			return best_path
	return best_path

static func _prepare_route(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	navigation_map: RID,
	raw_points: Array[Vector3],
	blocking_line: PackedVector3Array
) -> Array[Vector3]:
	var route: Array[Vector3] = []
	for raw_point in raw_points:
		var snapped_point := NavigationServer3D.map_get_closest_point(
			navigation_map,
			raw_point
		)
		if _horizontal_distance(raw_point, snapped_point) > NAV_SNAP_TOLERANCE:
			return []
		route.append(snapped_point)
	var previous_point := body.global_position
	for point in route:
		if not _navigation_segment_is_valid(
			navigation_map,
			previous_point,
			point
		):
			return []
		if not _physics_segment_is_clear(
			body,
			collision_shape,
			previous_point,
			point
		):
			return []
		previous_point = point
	if blocking_line.size() >= 2:
		if _route_crosses_blocking_line(body.global_position, route, blocking_line):
			return []
	return route

static func _route_crosses_blocking_line(
	start: Vector3,
	route: Array[Vector3],
	blocking_line: PackedVector3Array
) -> bool:
	if blocking_line.size() < 2:
		return false
	var line_a := Vector2(blocking_line[0].x, blocking_line[0].z)
	var line_b := Vector2(blocking_line[1].x, blocking_line[1].z)
	var previous := Vector2(start.x, start.z)
	for point in route:
		var current := Vector2(point.x, point.z)
		var intersection = Geometry2D.segment_intersects_segment(
			previous,
			current,
			line_a,
			line_b
		)
		if intersection != null:
			var hit := intersection as Vector2
			if hit.distance_to(previous) > 0.12 and hit.distance_to(current) > 0.12:
				return true
		previous = current
	return false

static func _navigation_segment_is_valid(
	navigation_map: RID,
	from_point: Vector3,
	to_point: Vector3
) -> bool:
	var distance : float = _horizontal_distance(from_point, to_point)
	if distance < 0.01:
		return false
	var steps := maxi(
		int(ceil(distance / NAV_SAMPLE_STEP)),
		1
	)
	for i in range(1, steps + 1):
		var weight : float = float(i) / float(steps)
		var sample : Vector3 = from_point.lerp(to_point, weight)
		var closest := NavigationServer3D.map_get_closest_point(
			navigation_map,
			sample
		)
		if _horizontal_distance(sample, closest) > NAV_SNAP_TOLERANCE:
			return false
	return true

static func _physics_segment_is_clear(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	from_point: Vector3,
	to_point: Vector3
) -> bool:
	var motion := to_point - from_point
	if motion.length_squared() < 0.0001:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _create_clearance_shape(collision_shape.shape)
	var shape_offset := collision_shape.global_position - body.global_position
	var start_transform := collision_shape.global_transform
	start_transform.origin = from_point + shape_offset
	query.transform = start_transform
	query.motion = motion
	query.exclude = [body.get_rid()]
	query.collision_mask = body.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var space_state := body.get_world_3d().direct_space_state
	var cast_result := space_state.cast_motion(query)
	if cast_result.is_empty():
		return false
	return cast_result[0] >= 0.999

static func _create_clearance_shape(source: Shape3D) -> Shape3D:
	if source is CapsuleShape3D:
		var source_capsule := source as CapsuleShape3D
		var capsule := CapsuleShape3D.new()
		capsule.radius = max(
			source_capsule.radius - SHAPE_SHRINK,
			0.05
		)
		capsule.height = max(
			source_capsule.height - SHAPE_SHRINK,
			capsule.radius * 2.0
		)
		return capsule
	if source is SphereShape3D:
		var source_sphere := source as SphereShape3D
		var sphere := SphereShape3D.new()
		sphere.radius = max(
			source_sphere.radius - SHAPE_SHRINK,
			0.05
		)
		return sphere
	return source

static func _route_cost(
	start: Vector3,
	route: Array[Vector3],
	final_target: Vector3
) -> float:
	var cost := 0.0
	var previous_point := start
	for point in route:
		cost += _horizontal_distance(previous_point, point)
		previous_point = point
	cost += _horizontal_distance(previous_point, final_target)
	return cost

static func _get_body_radius(shape: Shape3D) -> float:
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	return 0.3

static func _horizontal_distance(
	point_a: Vector3,
	point_b: Vector3
) -> float:
	return Vector2(
		point_a.x,
		point_a.z
	).distance_to(
		Vector2(
			point_b.x,
			point_b.z
		)
	)

static func find_safe_target(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	agent: NavigationAgent3D,
	requested_target: Vector3
) -> Vector3:
	var navigation_map := agent.get_navigation_map()
	if not navigation_map.is_valid():
		return requested_target
	var target: Vector3 = NavigationServer3D.map_get_closest_point(
		navigation_map,
		requested_target
	)
	var body_radius: float = _get_body_radius(collision_shape.shape)
	var search_step: float = maxf(body_radius * 0.5, 0.25)
	var max_search_radius: float = maxf(body_radius * 5.0, 3.0)
	var direction_count: int = 16
	var nearby_characters: Array[CharacterBody3D] = _get_nearby_characters(
		body,
		collision_shape,
		agent,
		target,
		max_search_radius
	)
	if _position_is_safe_target(
		body,
		collision_shape,
		agent,
		target,
		nearby_characters
	):
		return target
	var best_target: Vector3 = target
	var best_distance: float = INF
	var radius: float = search_step
	while radius <= max_search_radius:
		for i in range(direction_count):
			var angle: float = TAU * float(i) / float(direction_count)
			var offset := Vector3(
				cos(angle) * radius,
				0.0,
				sin(angle) * radius
			)
			var candidate: Vector3 = NavigationServer3D.map_get_closest_point(
				navigation_map,
				target + offset
			)
			if _horizontal_distance(
				candidate,
				target + offset
			) > NAV_SNAP_TOLERANCE:
				continue
			if not _position_is_safe_target(
				body,
				collision_shape,
				agent,
				candidate,
				nearby_characters
			):
				continue
			var distance_to_requested: float = _horizontal_distance(
				candidate,
				requested_target
			)
			if distance_to_requested < best_distance:
				best_distance = distance_to_requested
				best_target = candidate
		if best_distance < INF:
			return best_target
		radius += search_step
	return target

static func _position_is_clear(body: CharacterBody3D,
	collision_shape: CollisionShape3D, position: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _create_clearance_shape(collision_shape.shape)
	var shape_offset := collision_shape.global_position - body.global_position
	var test_transform := collision_shape.global_transform
	test_transform.origin = position + shape_offset
	query.transform = test_transform
	query.exclude = [body.get_rid()]
	query.collision_mask = body.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var space_state := body.get_world_3d().direct_space_state
	var results := space_state.intersect_shape(query, 1)
	return results.is_empty()

static func _position_is_safe_target(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	agent: NavigationAgent3D,
	position: Vector3,
	nearby_characters: Array[CharacterBody3D]
) -> bool:
	if not _position_is_clear(
		body,
		collision_shape,
		position
	):
		return false
	if not _position_has_agent_clearance(
		agent,
		position,
		nearby_characters
	):
		return false
	return true

static func _position_has_agent_clearance(
	agent: NavigationAgent3D,
	position: Vector3,
	nearby_characters: Array[CharacterBody3D]
) -> bool:
	for other_body in nearby_characters:
		if not is_instance_valid(other_body):
			continue
		var other_agent: NavigationAgent3D = other_body.get_node_or_null(
			"NavigationAgent3D"
		) as NavigationAgent3D
		if other_agent == null:
			continue
		var required_distance: float = (
			agent.radius
			+ other_agent.radius
			+ 0.05
		)
		if _horizontal_distance(
			position,
			other_body.global_position
		) < required_distance:
			return false
	return true

static func _get_nearby_characters(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	agent: NavigationAgent3D,
	position: Vector3,
	search_radius: float
) -> Array[CharacterBody3D]:
	var nearby_characters: Array[CharacterBody3D] = []
	var query_shape := SphereShape3D.new()
	query_shape.radius = search_radius + agent.radius * 3.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = query_shape
	var shape_offset: Vector3 = (
		collision_shape.global_position
		- body.global_position
	)
	var query_transform := Transform3D.IDENTITY
	query_transform.origin = position + shape_offset
	query.transform = query_transform
	query.exclude = [body.get_rid()]
	query.collision_mask = body.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var space_state := body.get_world_3d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(
		query,
		64
	)
	for result in results:
		var collider: Object = result.get("collider")
		if collider is CharacterBody3D:
			var other_body: CharacterBody3D = collider as CharacterBody3D
			if other_body != body and not nearby_characters.has(other_body):
				nearby_characters.append(other_body)
	return nearby_characters

static func find_short_escape(
	body: CharacterBody3D,
	collision_shape: CollisionShape3D,
	agent: NavigationAgent3D,
	forward_direction: Vector3
) -> Array[Vector3]:
	const STEP := 0.14
	const MIN_ESCAPE_DISTANCE := 0.70
	const FORWARD_CHECK := 0.75
	const MAX_RADIUS := 2.4
	const MAX_SEARCH_NODES := 400
	var navigation_map := agent.get_navigation_map()
	var empty_path: Array[Vector3] = []
	if not navigation_map.is_valid():
		return empty_path
	forward_direction.y = 0.0
	if forward_direction.length_squared() < 0.0001:
		return empty_path
	forward_direction = forward_direction.normalized()
	var start: Vector3 = body.global_position
	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1)
	]
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var parents: Dictionary = {}
	parents[Vector2i.ZERO] = Vector2i.ZERO
	var queue_index := 0
	while queue_index < queue.size() and queue_index < MAX_SEARCH_NODES:
		var cell: Vector2i = queue[queue_index]
		queue_index += 1
		var current := start + Vector3(
			float(cell.x) * STEP,
			0.0,
			float(cell.y) * STEP
		)
		if _horizontal_distance(start, current) >= MIN_ESCAPE_DISTANCE:
			var ahead: Vector3 = current + forward_direction * FORWARD_CHECK
			var can_rejoin := (
				_horizontal_distance(start, ahead) >= 0.4
				and _navigation_segment_is_valid(navigation_map, current, ahead)
				and _physics_segment_is_clear(
					body,
					collision_shape,
					current,
					ahead
				)
				and _position_is_clear(body, collision_shape, ahead)
			)
			if can_rejoin:
				var route: Array[Vector3] = []
				var trace: Vector2i = cell
				while trace != Vector2i.ZERO:
					route.push_front(
						start + Vector3(
							float(trace.x) * STEP,
							0.0,
							float(trace.y) * STEP
						)
					)
					var previous_cell: Vector2i = parents[trace]
					trace = previous_cell
				route.append(ahead)
				return route
		for offset in directions:
			var next_cell: Vector2i = cell + offset
			if parents.has(next_cell):
				continue
			var next_point := start + Vector3(
				float(next_cell.x) * STEP,
				0.0,
				float(next_cell.y) * STEP
			)
			if _horizontal_distance(start, next_point) > MAX_RADIUS:
				continue
			if not _navigation_segment_is_valid(
				navigation_map,
				current,
				next_point
			):
				continue
			if not _physics_segment_is_clear(
				body,
				collision_shape,
				current,
				next_point
			):
				continue
			if not _position_is_clear(body, collision_shape, next_point):
				continue
			parents[next_cell] = cell
			queue.append(next_cell)
	return empty_path
