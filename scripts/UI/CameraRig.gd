extends Node3D

@export var move_speed := 15.0
@export var edge_size := 20
@export var rotate_speed := 0.003
@export var zoom_min_y := 5.0
@export var zoom_max_y := 25.0
@export var zoom_step := 1.0

@export var ray_length := 500.0
# سرعت حرکت از زمین به بالای ساختمانها کمتر=کندتر
@export var follow_smooth_speed := 4.0
@export var debug_draw_enabled := false

# Layer 7 = CameraSurface
# زمین، شیب، کوه، سقف، پل و سطح‌هایی که Ray باید به آن‌ها بخورد.
const CAMERA_SURFACE_MASK := 1 << 6

@onready var camera: Camera3D = $Camera3D

@export_range(0.0, 89.0, 1.0)
var pitch_min_angle := 15.0

@export_range(0.0, 89.0, 1.0)
var pitch_max_angle := 75.0
var yaw := 0.0
var xaw := 0.0
var zoom_y := 0.0
var zoom_z := 0.0
var min_xaw := 0.0
var max_xaw := 0.0

func _ready():
	yaw = rotation.y
	xaw = rotation.x

	var camera_pitch := camera.rotation.x

	min_xaw = (
		deg_to_rad(-pitch_max_angle)
		- camera_pitch
	)

	max_xaw = (
		deg_to_rad(-pitch_min_angle)
		- camera_pitch
	)

	xaw = clampf(xaw, min_xaw, max_xaw)

	rotation.x = xaw

	zoom_y = camera.position.y
	zoom_z = camera.position.z


func _process(delta):
	_handle_movement(delta)
	_handle_keyboard_rotation()
	_follow_camera_ray_hit(delta)
	_apply_zoom()

	if debug_draw_enabled:
		_debug_draw_camera_ray()


func _input(event):
	_handle_zoom(event)
	_handle_alt_rotation(event)


func _handle_movement(delta):
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()

	var input_x = 0.0
	var input_z = 0.0

	if mouse_pos.x < edge_size:
		input_x -= 1.0
	if mouse_pos.x > viewport_size.x - edge_size:
		input_x += 1.0
	if mouse_pos.y < edge_size:
		input_z -= 1.0
	if mouse_pos.y > viewport_size.y - edge_size:
		input_z += 1.0

	if Input.is_action_pressed("camera_move_forward"):
		input_z -= 1.0
	if Input.is_action_pressed("camera_move_backward"):
		input_z += 1.0
	if Input.is_action_pressed("camera_move_right"):
		input_x += 1.0
	if Input.is_action_pressed("camera_move_left"):
		input_x -= 1.0

	var forward = Vector3(0, 0, 1).rotated(Vector3.UP, yaw)
	var right = Vector3(1, 0, 0).rotated(Vector3.UP, yaw)
	var move_dir = (right * input_x + forward * input_z).normalized()

	if move_dir == Vector3.ZERO:
		return

	var old_position = global_position
	var step = move_dir * move_speed * delta
	var next_position = old_position + step

	global_position = next_position
	force_update_transform()

	if not _is_camera_on_surface():
		global_position = _find_slide_position(old_position, step)
		force_update_transform()


func _handle_keyboard_rotation():
	if Input.is_action_pressed("camera_rotate_left"):
		yaw -= rotate_speed * 10.0

	if Input.is_action_pressed("camera_rotate_right"):
		yaw += rotate_speed * 10.0

	rotation.y = yaw


func _handle_alt_rotation(event):
	if Input.is_action_pressed("camera_rotate_modifier"):
		if event is InputEventMouseMotion:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			CursorManager.set_state(CursorManager.CursorState.ROTATE)

			yaw -= event.relative.x * rotate_speed
			rotation.y = yaw
			xaw -= event.relative.y * rotate_speed
			xaw = clampf(xaw, min_xaw, max_xaw)
			rotation.x = xaw
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		if HoverSystem.current_hover and HoverSystem.current_hover.has_method("get_cursor"):
			CursorManager.set_state(HoverSystem.current_hover.get_cursor())
		else:
			CursorManager.set_state(CursorManager.CursorState.DEFAULT)		#CursorManager.set_state(CursorManager.CursorState.DEFAULT)


func _handle_zoom(event):
	if event.is_action_pressed("camera_zoom_in") and zoom_y > zoom_min_y:
		zoom_y = max(zoom_min_y, zoom_y - zoom_step)
		zoom_z -= zoom_step

	elif event.is_action_pressed("camera_zoom_out") and zoom_y < zoom_max_y:
		zoom_y = min(zoom_max_y, zoom_y + zoom_step)
		zoom_z += zoom_step


func _apply_zoom():
	camera.position.y = zoom_y
	camera.position.z = zoom_z


func _follow_camera_ray_hit(delta):
	var hit = _raycast_from_camera()

	if hit.is_empty():
		return

	global_position = global_position.lerp(
		hit.position,
		delta * follow_smooth_speed
	)


func _is_camera_on_surface() -> bool:
	return not _raycast_from_camera().is_empty()


func _raycast_from_camera() -> Dictionary:
	var space_state = get_world_3d().direct_space_state

	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * ray_length

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = CAMERA_SURFACE_MASK

	return space_state.intersect_ray(query)


func _find_slide_position(old_position: Vector3, step: Vector3) -> Vector3:
	var best_position = old_position
	var best_score = -INF

	var angles = [
		-75.0, -60.0, -45.0, -30.0, -15.0,
		15.0, 30.0, 45.0, 60.0, 75.0
	]

	for angle in angles:
		var test_step = step.rotated(Vector3.UP, deg_to_rad(angle))
		var test_position = old_position + test_step

		global_position = test_position
		force_update_transform()

		if _is_camera_on_surface():
			var score = test_step.normalized().dot(step.normalized())

			if score > best_score:
				best_score = score
				best_position = test_position

	global_position = old_position
	force_update_transform()

	return best_position


func _debug_draw_camera_ray():
	if not debug_draw_enabled:
		return

	if not DebugDraw:
		return

	DebugDraw.clear()

	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z) * ray_length
	var hit = _raycast_from_camera()

	if hit.is_empty():
		DebugDraw.line(from, to, Color.RED)
	else:
		DebugDraw.line(from, hit.position, Color.GREEN)
		DebugDraw.line(hit.position, to, Color.RED)
		DebugDraw.cross(hit.position, 0.35, Color.YELLOW)

	DebugDraw.cross(from, 0.25, Color.CYAN)
