extends Node3D

enum AwarenessState {
	NORMAL,
	SUSPICIOUS,
	ALERT
}

enum VisibilityResult {
	BLOCKED,
	CROUCH_SAFE,
	FULL
}

#برای ساخت خطوط دید
@export_group("Debug Vision Rays")
@export var debug_draw_visibility_rays: bool = false
@export var debug_draw_only_visible_rays: bool = true
@export var debug_ray_head_color: Color = Color(1.0, 0.2, 0.2, 1.0)     # قرمز
@export var debug_ray_crouch_color: Color = Color(1.0, 0.9, 0.1, 1.0)   # زرد
@export var debug_ray_feet_color: Color = Color(0.1, 1.0, 0.3, 1.0)     # سبز
@export var debug_ray_hidden_color: Color = Color(0.35, 0.35, 0.35, 0.45)


@export_group("Vision")
@export var view_distance: float = 10.0:
	set(value):
		view_distance = max(value, 0.1)
@export_range(10.0, 170.0, 1.0)
var horizontal_view_angle: float = 70.0:
	set(value):
		horizontal_view_angle = clamp(value, 10.0, 170.0)
# Legacy total vertical angle kept for scene compatibility.
# Gameplay checks now use asymmetric up/down limits below.
@export_range(10.0, 180.0, 1.0)
var vertical_view_angle: float = 120.0
@export_range(0.0, 89.0, 1.0)
var vision_up_angle: float = 30.0
@export_range(0.0, 90.0, 1.0)
var vision_down_angle: float = 90.0
@export_range(0.1, 3.0, 0.05)
var eye_height: float = 1.6
@export_flags_3d_physics
var vision_collision_mask: int = 1


@export_group("Vision Colors")
@export var normal_color := Color(0.15, 0.75, 0.35, 0.28)
@export var suspicious_color := Color(1.0, 0.8, 0.1, 0.35)
@export var alert_color := Color(1.0, 0.15, 0.1, 0.4)
@export var vision_color: Color = Color( 0.15, 0.85, 0.25, 0.80)

@export_group("Environment")
@export_range(0.1, 1.0, 0.05)
var night_distance_multiplier: float = 0.65
@export var use_night_vision_limit: bool = false

@export_group("Vision Scan")
@export_range(0.0, 90.0, 1.0)
var scan_angle: float = 35.0
@export_range(1.0, 90.0, 1.0)
var scan_speed: float = 30.0
@export_range(0.0, 5.0, 0.1)
var scan_pause_time: float = 0.5
#جهت دیباگ دید
@export_group("Vision Debug")
var debug_target: CollisionObject3D = null
@export_range(0.1, 3.0, 0.05)
var debug_standing_height: float = 1.6
@export_range(0.1, 3.0, 0.05)
var debug_crouch_height: float = 0.7
@export_range(0.01, 0.1, 0.03)
var debug_feet_height: float = 0.03
#اتمام قسمت دیباگ

var scan_offset: float = 0.0
var scan_direction: float = 1.0
var scan_pause_remaining: float = 0.0

var awareness_state := AwarenessState.NORMAL
#برای ساخت خطوط دید
var _debug_ray_mesh_instance: MeshInstance3D
var _debug_ray_mesh: ImmediateMesh

#برای دیباگ
func _find_debug_target() -> void:
	debug_target = (
		get_tree().current_scene
		.find_child("Player", true, false)
		as CollisionObject3D
	)

func _ready() -> void:
	if debug_draw_visibility_rays:
		_setup_debug_ray_mesh()	
		#برای دیباگ
		call_deferred("_find_debug_target")

func _physics_process(_delta: float) -> void:
	if debug_draw_visibility_rays:
		_update_debug_visibility_rays()

func _process(delta: float) -> void:
	if scan_angle <= 0.0:
		if scan_offset != 0.0:
			scan_offset = 0.0
			scan_direction = 1.0
			scan_pause_remaining = 0.0
			rotation_degrees.y = 0.0

	else:
		if scan_pause_remaining > 0.0:
			scan_pause_remaining -= delta

		else:
			scan_offset += scan_direction * scan_speed * delta

			if scan_offset >= scan_angle:
				scan_offset = scan_angle
				scan_direction = -1.0
				scan_pause_remaining = scan_pause_time

			elif scan_offset <= -scan_angle:
				scan_offset = -scan_angle
				scan_direction = 1.0
				scan_pause_remaining = scan_pause_time

			rotation_degrees.y = scan_offset

func get_eye_position() -> Vector3:
	return global_position + global_basis.y.normalized() * eye_height

func get_effective_view_distance() -> float:
	if use_night_vision_limit:
		return view_distance * night_distance_multiplier

	return view_distance


func set_awareness_state(state: AwarenessState) -> void:
	awareness_state = state

func toggle_vision() -> void:
	VisionManager.toggle_vision(self)

func is_point_inside_fov(world_point: Vector3) -> bool:
	var eye_position := get_eye_position()
	var world_direction := world_point - eye_position

	if world_direction.length() > get_effective_view_distance():
		return false

	var local_direction := global_basis.inverse() * world_direction

	var horizontal_angle: float = abs(
		rad_to_deg(
			atan2(local_direction.x, local_direction.z)
		)
	)

	if horizontal_angle > horizontal_view_angle * 0.5:
		return false

	var horizontal_distance := Vector2(
		local_direction.x,
		local_direction.z
	).length()

	var vertical_angle: float = rad_to_deg(
		atan2(
			local_direction.y,
			maxf(
				horizontal_distance,
				0.0001
			)
		)
	)

	# Asymmetric gameplay vertical FOV:
	# +vision_up_angle above the horizon,
	# -vision_down_angle below the horizon.
	if vertical_angle > vision_up_angle:
		return false

	if vertical_angle < -vision_down_angle:
		return false

	return true

func _collect_collision_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append(node.get_rid())

	for child in node.get_children():
		_collect_collision_rids(child, out)

func has_line_of_sight(
	world_point: Vector3,
	target: CollisionObject3D = null
) -> bool:
	var eye_position: Vector3 = get_eye_position()

	var query := PhysicsRayQueryParameters3D.create(
		eye_position,
		world_point
	)

	query.collision_mask = vision_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var exclude: Array[RID] = []

	# همه کالایدرهای خود NPC مشاهده‌گر را exclude کن
	var owner_root: Node = get_parent()
	_collect_collision_rids(owner_root, exclude)

	# همه کالایدرهای هدف را هم exclude کن
	if target != null:
		_collect_collision_rids(target, exclude)

	query.exclude = exclude

	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)

	return result.is_empty()


func is_point_visible(
	world_point: Vector3,
	target: CollisionObject3D = null
) -> bool:

	if not is_point_inside_fov(world_point):
		return false

	if not has_line_of_sight(world_point, target):
		return false

	return true

func get_target_visibility(
    feet_point: Vector3,
    crouch_point: Vector3,
    standing_point: Vector3,
    target: CollisionObject3D = null
) -> VisibilityResult:

	var feet_visible := is_point_visible(feet_point,target)

	var crouch_visible := is_point_visible(crouch_point,target)

	var standing_visible := is_point_visible(standing_point,target)


	if feet_visible:
		return VisibilityResult.FULL
	

	if crouch_visible:
		return VisibilityResult.CROUCH_SAFE


	if standing_visible:
		return VisibilityResult.CROUCH_SAFE


	return VisibilityResult.BLOCKED
	
func _setup_debug_ray_mesh() -> void:
	if _debug_ray_mesh_instance != null:
		return

	_debug_ray_mesh = ImmediateMesh.new()

	_debug_ray_mesh_instance = MeshInstance3D.new()
	_debug_ray_mesh_instance.name = "DebugVisibilityRays"
	_debug_ray_mesh_instance.mesh = _debug_ray_mesh
	_debug_ray_mesh_instance.top_level = true
	_debug_ray_mesh_instance.global_transform = Transform3D.IDENTITY

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_debug_ray_mesh_instance.material_override = mat

	get_tree().current_scene.add_child(_debug_ray_mesh_instance)

func _add_debug_line(from_point: Vector3, to_point: Vector3, color: Color) -> void:
	_debug_ray_mesh.surface_set_color(color)
	_debug_ray_mesh.surface_add_vertex(from_point)
	_debug_ray_mesh.surface_add_vertex(to_point)

func _update_debug_visibility_rays() -> void:
	if _debug_ray_mesh == null:
		return
	_debug_ray_mesh.clear_surfaces()

	if !debug_draw_visibility_rays:
		return

	if debug_target == null:
		return

	var eye_point: Vector3 = global_position + Vector3.UP * eye_height

	var standing_point: Vector3 = (
		debug_target.global_position
		+ Vector3.UP * debug_standing_height
	)

	var crouch_point: Vector3 = (
		debug_target.global_position
		+ Vector3.UP * debug_crouch_height
	)

	var feet_point: Vector3 = (
		debug_target.global_position
		+ Vector3.UP * debug_feet_height
	)

	var standing_visible: bool = is_point_visible(standing_point,debug_target)

	var crouch_visible: bool = is_point_visible(crouch_point,debug_target)

	var feet_visible: bool = is_point_visible(feet_point,debug_target)

	_debug_ray_mesh.surface_begin(Mesh.PRIMITIVE_LINES)


	# Standing / Head
	_add_debug_line(
		eye_point,
		standing_point,
		debug_ray_head_color
		if standing_visible
		else debug_ray_hidden_color
	)

	# Crouch
	_add_debug_line(
		eye_point,
		crouch_point,
		debug_ray_crouch_color
		if crouch_visible
		else debug_ray_hidden_color
	)

	# Feet
	_add_debug_line(
		eye_point,
		feet_point,
		debug_ray_feet_color
		if feet_visible
		else debug_ray_hidden_color
	)

	_debug_ray_mesh.surface_end()