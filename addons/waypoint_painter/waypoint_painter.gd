@tool
extends EditorPlugin

const DRAFT_NAME := "WaypointDraft"
const POINT_PREFIX := "Point_"
const PICK_RADIUS := 14.0
const LABEL_NAME := "_WaypointNumber"

var paint_button: Button
var paint_enabled := false

var dragged_point: Marker3D
var drag_start_position := Vector3.ZERO


func _enter_tree() -> void:
	paint_button = Button.new()
	paint_button.text = "Waypoint Paint"
	paint_button.toggle_mode = true
	paint_button.toggled.connect(_on_paint_toggled)

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, paint_button)
	set_input_event_forwarding_always_enabled()


func _exit_tree() -> void:
	paint_enabled = false
	dragged_point = null

	if paint_button != null:
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, paint_button)
		paint_button.queue_free()


func _on_paint_toggled(enabled: bool) -> void:
	paint_enabled = enabled
	paint_button.text = "✓ Waypoint Paint" if enabled else "Waypoint Paint"

	_set_draft_visibility(enabled)

	if enabled:
		_update_waypoint_numbers()
	else:
		dragged_point = null


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if not paint_enabled:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			paint_button.button_pressed = false
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var point := _get_point_under_mouse(viewport_camera, event.position)

		if point != null:
			_remove_waypoint(point)
			_update_waypoint_numbers()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var point := _get_point_under_mouse(viewport_camera, event.position)

			if point != null:
				_start_drag(point)
				return EditorPlugin.AFTER_GUI_INPUT_STOP

			var waypoint_position = _get_valid_waypoint_position(viewport_camera, event.position)

			if waypoint_position != null:
				_add_waypoint(waypoint_position)
				_update_waypoint_numbers()

			return EditorPlugin.AFTER_GUI_INPUT_STOP

		if dragged_point != null:
			_finish_drag()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion and dragged_point != null:
		var waypoint_position = _get_valid_waypoint_position(viewport_camera, event.position)

		if waypoint_position != null:
			dragged_point.global_position = waypoint_position

		return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _remove_waypoint(point: Marker3D) -> void:
	if point == null or not is_instance_valid(point):
		return

	var parent := point.get_parent()

	if parent == null:
		return

	var index := point.get_index()
	var undo_redo := get_undo_redo()

	undo_redo.create_action("Remove Waypoint")

	undo_redo.add_do_method(parent, "remove_child", point)

	undo_redo.add_undo_method(parent, "add_child", point)
	undo_redo.add_undo_method(parent, "move_child", point, index)

	undo_redo.add_do_reference(point)

	undo_redo.commit_action()


func _add_waypoint(world_position: Vector3) -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()

	if scene_root == null:
		return

	var container := scene_root.get_node_or_null(DRAFT_NAME) as Node3D
	var point := Marker3D.new()

	if container == null:
		container = Node3D.new()
		container.name = DRAFT_NAME
		container.visible = paint_enabled

		point.name = "%s%03d" % [POINT_PREFIX, 1]

		var undo_redo := get_undo_redo()
		undo_redo.create_action("Add Waypoint")

		undo_redo.add_do_method(scene_root, "add_child", container)
		undo_redo.add_do_method(container, "set_owner", scene_root)
		undo_redo.add_do_method(container, "add_child", point)
		undo_redo.add_do_method(point, "set_owner", scene_root)
		undo_redo.add_do_property(point, "global_position", world_position)

		undo_redo.add_do_reference(container)
		undo_redo.add_do_reference(point)

		undo_redo.add_undo_method(container, "remove_child", point)
		undo_redo.add_undo_method(scene_root, "remove_child", container)

		undo_redo.commit_action()
		return

	point.name = _get_next_point_name(container)

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add Waypoint")

	undo_redo.add_do_method(container, "add_child", point)
	undo_redo.add_do_method(point, "set_owner", scene_root)
	undo_redo.add_do_property(point, "global_position", world_position)
	undo_redo.add_do_reference(point)

	undo_redo.add_undo_method(container, "remove_child", point)

	undo_redo.commit_action()


func _get_next_point_name(container: Node) -> String:
	var index := 1

	while true:
		var point_name := "%s%03d" % [POINT_PREFIX, index]

		if container.get_node_or_null(point_name) == null:
			return point_name

		index += 1

	return ""


func _start_drag(point: Marker3D) -> void:
	dragged_point = point
	drag_start_position = point.global_position


func _finish_drag() -> void:
	if dragged_point == null:
		return

	var final_position := dragged_point.global_position

	if final_position.distance_to(drag_start_position) > 0.001:
		var undo_redo := get_undo_redo()
		undo_redo.create_action("Move Waypoint")
		undo_redo.add_do_property(dragged_point, "global_position", final_position)
		undo_redo.add_undo_property(dragged_point, "global_position", drag_start_position)
		undo_redo.commit_action()

	dragged_point = null


func _get_point_under_mouse(camera: Camera3D, mouse_position: Vector2) -> Marker3D:
	var scene_root := get_editor_interface().get_edited_scene_root()

	if scene_root == null:
		return null

	var container := scene_root.get_node_or_null(DRAFT_NAME)

	if container == null:
		return null

	var closest_point: Marker3D
	var closest_distance := PICK_RADIUS

	for child in container.get_children():
		if not child is Marker3D:
			continue

		var point := child as Marker3D

		if camera.is_position_behind(point.global_position):
			continue

		var screen_position := camera.unproject_position(point.global_position)
		var distance := screen_position.distance_to(mouse_position)

		if distance <= closest_distance:
			closest_distance = distance
			closest_point = point

	return closest_point

func _get_valid_waypoint_position(camera: Camera3D, mouse_position: Vector2) -> Variant:
	var surface_hit := _get_surface_hit(camera, mouse_position)

	if surface_hit.is_empty():
		return null

	var surface_position: Vector3 = surface_hit.position

	if not _has_navmesh_above(surface_position):
		return null

	return surface_position

func _get_surface_hit(camera: Camera3D, mouse_position: Vector2) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()

	if scene_root == null or not scene_root is Node3D:
		return {}

	var from := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var to := from + direction * 1000.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var space_state := (scene_root as Node3D).get_world_3d().direct_space_state
	return space_state.intersect_ray(query)

func _has_navmesh_above(surface_position: Vector3) -> bool:
	var scene_root := get_editor_interface().get_edited_scene_root()

	if scene_root == null:
		return false

	var regions: Array[NavigationRegion3D] = []
	_find_navigation_regions(scene_root, regions)

	var ray_origin := surface_position + Vector3.UP * 2.0
	var ray_direction := Vector3.DOWN

	for region in regions:
		if not region.enabled:
			continue

		var navigation_mesh := region.navigation_mesh

		if navigation_mesh == null:
			continue

		if navigation_mesh.get_polygon_count() == 0:
			continue

		var vertices := navigation_mesh.get_vertices()
		var region_transform := region.global_transform

		for polygon_index in range(navigation_mesh.get_polygon_count()):
			var polygon := navigation_mesh.get_polygon(polygon_index)

			if polygon.size() < 3:
				continue

			var vertex_a := region_transform * vertices[polygon[0]]

			for index in range(1, polygon.size() - 1):
				var vertex_b := region_transform * vertices[polygon[index]]
				var vertex_c := region_transform * vertices[polygon[index + 1]]

				var hit = Geometry3D.ray_intersects_triangle(
					ray_origin,
					ray_direction,
					vertex_a,
					vertex_b,
					vertex_c
				)

				if hit != null:
					if hit.y >= surface_position.y - 0.05:
						return true

	return false


func _find_navigation_regions(node: Node, regions: Array[NavigationRegion3D]) -> void:
	if node is NavigationRegion3D:
		regions.append(node)

	for child in node.get_children():
		_find_navigation_regions(child, regions)

func _set_draft_visibility(value: bool) -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()

	if scene_root == null:
		return

	var container := scene_root.get_node_or_null(DRAFT_NAME) as Node3D

	if container != null:
		container.visible = value

func _update_waypoint_numbers() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()

	if scene_root == null:
		return

	var container := scene_root.get_node_or_null(DRAFT_NAME) as Node3D

	if container == null:
		return

	var index := 1

	for child in container.get_children():
		if not child is Marker3D:
			continue

		var point := child as Marker3D
		var label := point.get_node_or_null(LABEL_NAME) as Label3D

		if label == null:
			label = Label3D.new()
			label.name = LABEL_NAME
			label.position = Vector3(0.0, 0.35, 0.0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.fixed_size = true
			label.font_size = 24
			point.add_child(label)

		label.text = str(index)
		label.visible = paint_enabled

		index += 1


