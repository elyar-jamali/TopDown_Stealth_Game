extends Node


const VisionDepthEffect := preload(
	"res://scripts/AI/vision_depth_effect.gd"
)
const VisionReceiverShader := preload(
	"res://data/shaders/vision_receiver.gdshader"
)
const VisionTopDepthEffect := preload(
	"res://scripts/AI/vision_top_depth_effect.gd"
)

var vision_receiver_material: ShaderMaterial = null

var active_vision: Node3D = null

var vision_viewport: SubViewport = null
var vision_camera: Camera3D = null

# Guard depth-map compositor.
var vision_compositor: Compositor = null
var vision_depth_effect = null
var vision_depth_texture: Texture2D = null
var vision_color: Color = Color(0.15,0.85,0.25,0.80)

# Top orthographic height/depth camera.
var top_vision_viewport: SubViewport = null
var top_vision_camera: Camera3D = null

var top_vision_compositor: Compositor = null
var top_vision_depth_effect = null
var top_vision_depth_texture: Texture2D = null


@export_group("Top Vision Depth")
@export_range(4.0, 64.0, 1.0)
var top_depth_pixels_per_meter: float = 32.0
@export_range(64, 1024, 8)
var top_depth_max_axis: int = 512
@export_range(32, 256, 8)
var top_depth_min_axis: int = 64
@export_range(0.0, 2.0, 0.1)
var top_depth_padding: float = 0.5
@export_range(2.0, 30.0, 0.5)
var top_depth_camera_height: float = 8.0
@export_range(4.0, 60.0, 0.5)
var top_depth_vertical_range: float = 16.0

func _ready() -> void:
	_create_vision_camera()
	_create_top_vision_camera()
	_create_vision_receiver_material()

func _process(_delta: float) -> void:
	if active_vision == null:
		return

	_update_vision_camera()
	_update_top_vision_camera()
	_update_vision_receiver()


func _create_vision_camera() -> void:
	vision_viewport = SubViewport.new()
	vision_viewport.name = "VisionViewport"
	vision_viewport.size = Vector2i(1024, 1024)

	# در حالت عادی GPU برای VisionCamera کار نکند
	vision_viewport.render_target_update_mode = (
		SubViewport.UPDATE_DISABLED
	)

	vision_viewport.gui_disable_input = true

	add_child(vision_viewport)

	vision_camera = Camera3D.new()
	vision_camera.name = "VisionCamera"

	vision_camera.current = true
	vision_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	vision_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	vision_camera.frustum_offset = Vector2.ZERO
	vision_camera.h_offset = 0.0
	vision_camera.v_offset = 0.0
	vision_camera.near = 0.05

	# Layer 17 = Vision visuals.
	vision_camera.set_cull_mask_value(17, false)

	# Layer 18 = Characters.
	vision_camera.set_cull_mask_value(18, false)

	# Layer 19 = Passive outline proxies.
	vision_camera.set_cull_mask_value(19, false)

	# Layer 20 = Active outline proxies.
	vision_camera.set_cull_mask_value(20, false)

	vision_depth_effect = VisionDepthEffect.new()

	vision_depth_texture = (
		vision_depth_effect.get_depth_texture()
	)

	vision_compositor = Compositor.new()

	vision_compositor.compositor_effects = [
		vision_depth_effect
	]

	vision_camera.compositor = vision_compositor

	vision_viewport.add_child(vision_camera)

func _create_top_vision_camera() -> void:

	top_vision_viewport = SubViewport.new()

	top_vision_viewport.name = (
		"TopVisionViewport"
	)

	# Temporary initial size.
	# Real size is calculated from each guard's FOV.
	top_vision_viewport.size = Vector2i(128,128)

	top_vision_viewport.render_target_update_mode = (
		SubViewport.UPDATE_DISABLED
	)

	top_vision_viewport.gui_disable_input = true


	add_child(
		top_vision_viewport
	)


	top_vision_camera = Camera3D.new()

	top_vision_camera.name = (
		"TopVisionCamera"
	)

	top_vision_camera.current = true

	top_vision_camera.projection = (
		Camera3D.PROJECTION_ORTHOGONAL
	)


	
	#The horizontal screen axis will follow
	#the guard's forward direction.

	#So orthographic width = FOV length.
	
	top_vision_camera.keep_aspect = (
		Camera3D.KEEP_WIDTH
	)


	top_vision_camera.near = 0.05

	top_vision_camera.far = (
		top_depth_vertical_range
	)


	# Same exclusions as Guard VisionCamera.

	# Layer 17 = Vision visuals.
	top_vision_camera.set_cull_mask_value(
		17,
		false
	)

	# Layer 18 = Characters.
	top_vision_camera.set_cull_mask_value(
		18,
		false
	)

	# Layer 19 = Passive outlines.
	top_vision_camera.set_cull_mask_value(
		19,
		false
	)

	# Layer 20 = Active outlines.
	top_vision_camera.set_cull_mask_value(
		20,
		false
	)


	top_vision_depth_effect = (
		VisionTopDepthEffect.new()
	)


	top_vision_depth_texture = (
		top_vision_depth_effect
		.get_depth_texture()
	)


	top_vision_compositor = Compositor.new()

	top_vision_compositor.compositor_effects = [
		top_vision_depth_effect
	]


	top_vision_camera.compositor = (
		top_vision_compositor
	)


	top_vision_viewport.add_child(
		top_vision_camera
	)

func _round_up_to_multiple(
	value: int,
	multiple: int
) -> int:

	if multiple <= 1:
		return value

	return int(
		ceil(
			float(value)
			/
			float(multiple)
		)
	) * multiple


func _calculate_top_viewport_size(
	coverage_length: float,
	coverage_width: float
) -> Vector2i:

	var raw_width := maxf(
		coverage_length
		* top_depth_pixels_per_meter,
		1.0
	)

	var raw_height := maxf(
		coverage_width
		* top_depth_pixels_per_meter,
		1.0
	)


	# Preserve aspect ratio if either axis exceeds
	# the configured maximum resolution.
	var largest_axis := maxf(
		raw_width,
		raw_height
	)


	var resolution_scale := 1.0

	if largest_axis > float(
		top_depth_max_axis
	):
		resolution_scale = (
			float(top_depth_max_axis)
			/
			largest_axis
		)


	var width_px := ceili(
		raw_width
		* resolution_scale
	)

	var height_px := ceili(
		raw_height
		* resolution_scale
	)


	width_px = clampi(
		width_px,
		top_depth_min_axis,
		top_depth_max_axis
	)

	height_px = clampi(
		height_px,
		top_depth_min_axis,
		top_depth_max_axis
	)


	# Compute shader uses 8×8 workgroups.
	width_px = _round_up_to_multiple(
		width_px,
		8
	)

	height_px = _round_up_to_multiple(
		height_px,
		8
	)


	width_px = mini(
		width_px,
		top_depth_max_axis
	)

	height_px = mini(
		height_px,
		top_depth_max_axis
	)


	return Vector2i(
		width_px,
		height_px
	)

func toggle_vision(vision: Node) -> void:
	if vision == null:
		return

	if not vision is Node3D:
		return

	# همان گارد دوباره انتخاب شد → خاموش
	if active_vision == vision:
		clear_vision()
		return

	# FOV گارد قبلی خاموش شود
	if active_vision != null:
		active_vision = null

	active_vision = vision as Node3D

	# فقط زمانی که FOV فعال است Depth Viewport رندر شود
	if vision_viewport != null:
		vision_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS
		)

	if top_vision_viewport != null:
		top_vision_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS
		)

	# Immediate update
	_apply_vision_receiver_materials()
	_update_vision_camera()
	_update_top_vision_camera()
	_update_vision_receiver()


func clear_vision() -> void:
	active_vision = null

	# دیگر نیازی به رندر depth نداریم
	if vision_viewport != null:
		vision_viewport.render_target_update_mode = (
			SubViewport.UPDATE_DISABLED
		)

	if vision_receiver_material != null:
		vision_receiver_material.set_shader_parameter(
			"vision_enabled",
			false
		)
	if top_vision_viewport != null:
		top_vision_viewport.render_target_update_mode = (
			SubViewport.UPDATE_DISABLED
		)


func _update_vision_camera() -> void:
	if active_vision == null:
		return

	if vision_camera == null:
		return

	if vision_viewport == null:
		return

	# VisionViewport must render the same 3D world as the active guard.
	var world: World3D = active_vision.get_world_3d()

	if vision_viewport.world_3d != world:
		vision_viewport.world_3d = world

	# VisionComponent uses +Z as forward.
	# Camera3D looks toward -Z, so rotate by 180 degrees around world up.
	var camera_transform: Transform3D = active_vision.global_transform

	camera_transform.basis = camera_transform.basis.rotated(
		Vector3.UP,
		PI
	)

	# Keep the depth camera horizontal. The old -15 degree tilt caused its
	camera_transform.basis = (
		camera_transform.basis.rotated(
			camera_transform.basis.x.normalized(),
			deg_to_rad(-15.0)
		)
	)
	# frustum to disagree with the horizontal gameplay FOV.
	vision_camera.global_transform = camera_transform

	# Place the depth camera at guard eye height.
	if active_vision.has_method("get_eye_position"):
		vision_camera.global_position = active_vision.get_eye_position()

	
	vision_camera.fov = (active_vision.vision_up_angle + 15.0) * 2.0
	# Match guard vision distance.
	if active_vision.has_method("get_effective_view_distance"):
		var view_distance: float = (
			active_vision.get_effective_view_distance()
		)

		vision_camera.far = max(
			view_distance + 2.0,
			view_distance * 1.2
		)

	# The compositor must use the actual camera planes used this frame.
	if vision_depth_effect != null:
		vision_depth_effect.set_camera_planes(
			vision_camera.near,
			vision_camera.far
		)

func _create_vision_receiver_material() -> void:
	vision_receiver_material = ShaderMaterial.new()

	vision_receiver_material.shader = (
		VisionReceiverShader
	)

	vision_receiver_material.set_shader_parameter(
		"vision_enabled",
		false
	)

func _apply_vision_receiver_materials() -> void:
	if vision_receiver_material == null:
		return

	var receivers := get_tree().get_nodes_in_group(
		"vision_receiver"
	)

	for receiver in receivers:
		_apply_receiver_recursive(
			receiver
		)

func _apply_receiver_recursive(node: Node) -> void:

	if node.has_meta("vision_receiver_proxy"):
		return


	var original_children := node.get_children()


	if node is MeshInstance3D:
		var source := node as MeshInstance3D

		if source.mesh != null:
			var existing := source.get_node_or_null(
				"VisionReceiverProxy"
			)

			if existing == null:
				var proxy := MeshInstance3D.new()

				proxy.name = "VisionReceiverProxy"

				proxy.set_meta(
					"vision_receiver_proxy",
					true
				)

				# دقیقاً همان هندسه‌ی سطح واقعی.
				proxy.mesh = source.mesh

				proxy.material_override = (
					vision_receiver_material
				)

				# فقط Vision layer.
				proxy.layers = 0

				proxy.set_layer_mask_value(
					17,
					true
				)

				proxy.cast_shadow = (
					GeometryInstance3D
					.SHADOW_CASTING_SETTING_OFF
				)

				source.add_child(proxy)


	for child in original_children:
		_apply_receiver_recursive(
			child
		)


func _update_vision_receiver() -> void:
	if vision_receiver_material == null:
		return

	if active_vision == null:
		vision_receiver_material.set_shader_parameter(
			"vision_enabled",
			false
		)
		return

	if vision_camera == null:
		return

	if top_vision_camera == null:
		return


	var guard_camera_transform: Transform3D = (
		vision_camera.get_camera_transform()
	)

	var guard_view_transform: Transform3D = (
		guard_camera_transform.affine_inverse()
	)

	var guard_projection: Projection = (
		vision_camera.get_camera_projection()
	)


	vision_receiver_material.set_shader_parameter(
		"guard_view_matrix",
		guard_view_transform
	)

	vision_receiver_material.set_shader_parameter(
		"guard_projection_matrix",
		guard_projection
	)


	var top_camera_transform: Transform3D = (
		top_vision_camera.get_camera_transform()
	)

	var top_view_transform: Transform3D = (
		top_camera_transform.affine_inverse()
	)

	var top_projection: Projection = (
		top_vision_camera.get_camera_projection()
	)


	vision_receiver_material.set_shader_parameter(
		"top_view_matrix",
		top_view_transform
	)

	vision_receiver_material.set_shader_parameter(
		"top_projection_matrix",
		top_projection
	)

	vision_receiver_material.set_shader_parameter(
		"top_far_plane",
		top_vision_camera.far
	)

	vision_receiver_material.set_shader_parameter(
		"top_near_plane",
		top_vision_camera.near
	)

	if top_vision_depth_texture != null:
		vision_receiver_material.set_shader_parameter(
			"top_depth_texture",
			top_vision_depth_texture
		)


	if active_vision.has_method(
		"get_eye_position"
	):
		vision_receiver_material.set_shader_parameter(
			"guard_world_position",
			active_vision.get_eye_position()
		)
	else:
		vision_receiver_material.set_shader_parameter(
			"guard_world_position",
			active_vision.global_position
		)


	var guard_forward: Vector3 = (
		active_vision.global_basis.z.normalized()
	)

	vision_receiver_material.set_shader_parameter(
		"guard_forward",
		guard_forward
	)


	vision_receiver_material.set_shader_parameter(
		"guard_horizontal_angle",
		active_vision.horizontal_view_angle
	)
	var guard_up_angle: float = 30.0
	var guard_down_angle: float = 90.0

	if "vision_up_angle" in active_vision:
		guard_up_angle = active_vision.vision_up_angle
	elif "vertical_view_angle" in active_vision:
		# Legacy fallback: reserve 30 degrees upward,
		# use the remaining total vertical angle downward.
		guard_up_angle = minf(
			30.0,
			active_vision.vertical_view_angle
		)
		guard_down_angle = maxf(
			active_vision.vertical_view_angle
			- guard_up_angle,
			0.0
		)

	if "vision_down_angle" in active_vision:
		guard_down_angle = active_vision.vision_down_angle

	vision_receiver_material.set_shader_parameter(
		"guard_up_angle",
		guard_up_angle
	)

	vision_receiver_material.set_shader_parameter(
		"guard_down_angle",
		guard_down_angle
	)


	vision_receiver_material.set_shader_parameter(
		"guard_view_distance",
		active_vision.get_effective_view_distance()
	)


	vision_receiver_material.set_shader_parameter(
		"guard_far_plane",
		vision_camera.far
	)


	if vision_depth_texture != null:
		vision_receiver_material.set_shader_parameter(
			"guard_depth_texture",
			vision_depth_texture
		)


	if "vision_color" in active_vision:
		vision_receiver_material.set_shader_parameter(
			"vision_color",
			active_vision.vision_color
		)


	vision_receiver_material.set_shader_parameter(
		"vision_enabled",
		true
	)

func _update_top_vision_camera() -> void:

	if active_vision == null:
		return

	if top_vision_camera == null:
		return

	if top_vision_viewport == null:
		return


	var world: World3D = (
		active_vision.get_world_3d()
	)


	if top_vision_viewport.world_3d != world:
		top_vision_viewport.world_3d = world


	# Gameplay forward is +Z.
	var forward := (
		active_vision
		.global_basis
		.z
	)

	forward.y = 0.0


	if forward.length_squared() < 0.0001:
		return


	forward = forward.normalized()


	# World-horizontal right vector.
	var right := (
		Vector3.UP
		.cross(forward)
		.normalized()
	)


	var view_distance: float = (
		active_vision
		.get_effective_view_distance()
	)


	var view_angle: float = (
		active_vision
		.horizontal_view_angle
	)


	# Width of the gameplay cone at its far edge.
	var far_width := (
		2.0
		*
		view_distance
		*
		tan(
			deg_to_rad(
				view_angle * 0.5
			)
		)
	)


	# Rectangle enclosing the complete gameplay cone.
	var coverage_length := maxf(
		view_distance
		+ top_depth_padding * 2.0,
		1.0
	)

	var coverage_width := maxf(
		far_width
		+ top_depth_padding * 2.0,
		1.0
	)


	"""
	Top camera local axes:

	X = guard forward
	Y = guard right
	Z = world up

	Camera3D looks along local -Z,
	therefore it looks straight down.
	"""
	var top_basis := Basis(
		forward,
		right,
		Vector3.UP
	)


	# Rectangle center is halfway along the FOV.
	var center := (
		active_vision.global_position
		+
		forward
		* (
			view_distance * 0.5
		)
	)


	# Camera itself stays above the gameplay region.
	center.y = (
		active_vision.global_position.y
		+ top_depth_camera_height
	)


	top_vision_camera.global_transform = (
		Transform3D(
			top_basis,
			center
		)
	)


	# KEEP_WIDTH means this controls the world-space
	# horizontal extent, which is aligned with FOV length.
	top_vision_camera.size = (coverage_length)


	top_vision_camera.far = (top_depth_vertical_range)


	# Adaptive resolution.
	var desired_size := (
		_calculate_top_viewport_size(
			coverage_length,
			coverage_width
		)
	)


	if (
		top_vision_viewport.size
		!= desired_size
	):
		top_vision_viewport.size = (
			desired_size
		)

	if top_vision_depth_effect != null:
		top_vision_depth_effect.set_camera_planes(
			top_vision_camera.near,
			top_vision_camera.far
		)
