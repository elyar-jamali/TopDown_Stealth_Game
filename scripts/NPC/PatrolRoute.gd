class_name PatrolRoute
extends Node3D

func get_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []

	for child in get_children():
		if child is Marker3D:
			points.append(child as Marker3D)

	return points

func get_point_count() -> int:
	return get_points().size()

func get_point(index: int) -> Marker3D:
	var points := get_points()

	if index < 0 or index >= points.size():
		return null

	return points[index]

func get_point_position(index: int) -> Vector3:
	var point := get_point(index)

	if point == null:
		return global_position

	return point.global_position