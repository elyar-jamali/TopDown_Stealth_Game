extends CompositorEffect

const DEPTH_SHADER_PATH := "res://data/shaders/vision_depth.glsl"

var rd: RenderingDevice = null
var shader: RID
var pipeline: RID
var nearest_sampler: RID

# Dedicated GPU texture containing only normalized linear depth.
var depth_output_rid: RID
var depth_output_size := Vector2i.ZERO
var depth_texture := Texture2DRD.new()

# If the render size ever changes, keep old RIDs alive until this effect is
# destroyed. This avoids invalidating a Texture2DRD while RenderingServer is
# asynchronously replacing its wrapped RD texture.
var retired_depth_rids: Array[RID] = []

# These values are written by the game thread and read by the render thread.
var plane_mutex := Mutex.new()
var near_plane: float = 0.05
var far_plane: float = 12.6


func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE
	access_resolved_depth = true

	rd = RenderingServer.get_rendering_device()

	if rd != null:
		var sampler_state := RDSamplerState.new()
		sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
		nearest_sampler = rd.sampler_create(sampler_state)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return

	if rd == null:
		return

	# Disconnect the Godot Texture2D wrapper first.
	if depth_texture != null:
		depth_texture.texture_rd_rid = RID()

	if pipeline.is_valid():
		rd.free_rid(pipeline)

	if shader.is_valid():
		rd.free_rid(shader)

	if nearest_sampler.is_valid():
		rd.free_rid(nearest_sampler)

	if depth_output_rid.is_valid():
		rd.free_rid(depth_output_rid)

	for old_rid: RID in retired_depth_rids:
		if old_rid.is_valid():
			rd.free_rid(old_rid)


func get_depth_texture() -> Texture2DRD:
	# The Texture2DRD object is stable. Its RD RID is attached on the render
	# thread as soon as the first guard-camera frame is processed.
	return depth_texture

func _attach_depth_output_rid(
	new_rid: RID
) -> void:
	if not new_rid.is_valid():
		return

	if depth_texture == null:
		return

	if depth_texture.texture_rd_rid == new_rid:
		return

	depth_texture.texture_rd_rid = new_rid

func _ensure_shader() -> bool:
	if rd == null:
		return false

	if pipeline.is_valid():
		return true

	var resource: Resource = ResourceLoader.load(
		DEPTH_SHADER_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)

	if resource == null:
		push_error("Could not load vision depth shader.")
		return false

	if not resource is RDShaderFile:
		push_error(
			"Vision depth shader is not RDShaderFile. Type: "
			+ resource.get_class()
		)
		return false

	var shader_file := resource as RDShaderFile
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()

	if shader_spirv.compile_error_compute != "":
		push_error(shader_spirv.compile_error_compute)
		return false

	shader = rd.shader_create_from_spirv(shader_spirv)

	if not shader.is_valid():
		push_error("Could not create vision depth shader.")
		return false

	pipeline = rd.compute_pipeline_create(shader)

	if not pipeline.is_valid():
		push_error("Could not create vision depth compute pipeline.")
		return false

	return true


func _ensure_depth_output(size: Vector2i) -> bool:
	if rd == null:
		return false

	if (
		depth_output_rid.is_valid()
		and depth_output_size == size
	):
		return true

	var usage_bits := (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	)

	if not rd.texture_is_format_supported_for_usage(
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,
		usage_bits
	):
		push_error(
			"R32_SFLOAT is not supported for the required vision-depth usage."
		)
		return false

	var texture_format := RDTextureFormat.new()
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	texture_format.width = size.x
	texture_format.height = size.y
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.samples = RenderingDevice.TEXTURE_SAMPLES_1
	texture_format.usage_bits = usage_bits

	var texture_view := RDTextureView.new()
	var new_rid: RID = rd.texture_create(
		texture_format,
		texture_view
	)

	if not new_rid.is_valid():
		push_error("Could not create dedicated vision depth texture.")
		return false

	if depth_output_rid.is_valid():
		retired_depth_rids.append(depth_output_rid)

	depth_output_rid = new_rid
	depth_output_size = size

	# IMPORTANT:
	# Do not mutate Texture2DRD from the CompositorEffect render callback.
	# Defer the wrapper update to the main thread / idle phase.
	call_deferred(
		"_attach_depth_output_rid",
		depth_output_rid
	)

	return true


func _render_callback(
	p_effect_callback_type: int,
	p_render_data: RenderData
) -> void:
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_OPAQUE:
		return

	if not _ensure_shader():
		return

	var render_scene_buffers := (
		p_render_data.get_render_scene_buffers()
	) as RenderSceneBuffersRD

	if render_scene_buffers == null:
		return

	var size: Vector2i = render_scene_buffers.get_internal_size()

	if size.x <= 0 or size.y <= 0:
		return

	if not _ensure_depth_output(size):
		return

	# VisionViewport is a normal single-view viewport. Use view 0 explicitly.
	if render_scene_buffers.get_view_count() < 1:
		return

	var depth_image: RID = render_scene_buffers.get_depth_layer(0)

	if not depth_image.is_valid():
		return

	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output_uniform.binding = 0
	output_uniform.add_id(depth_output_rid)

	var depth_uniform := RDUniform.new()
	depth_uniform.uniform_type = (
		RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	)
	depth_uniform.binding = 1
	depth_uniform.add_id(nearest_sampler)
	depth_uniform.add_id(depth_image)

	var uniform_set: RID = UniformSetCacheRD.get_cache(
		shader,
		0,
		[
			output_uniform,
			depth_uniform
		]
	)

	plane_mutex.lock()
	var current_near := near_plane
	var current_far := far_plane
	plane_mutex.unlock()

	var push_constant := PackedFloat32Array([
		float(size.x),
		float(size.y),
		current_near,
		current_far,
	])

	var x_groups: int = ceili(float(size.x) / 8.0)
	var y_groups: int = ceili(float(size.y) / 8.0)

	var compute_list: int = rd.compute_list_begin()

	rd.compute_list_bind_compute_pipeline(
		compute_list,
		pipeline
	)

	rd.compute_list_bind_uniform_set(
		compute_list,
		uniform_set,
		0
	)

	var push_bytes: PackedByteArray = push_constant.to_byte_array()

	rd.compute_list_set_push_constant(
		compute_list,
		push_bytes,
		push_bytes.size()
	)

	rd.compute_list_dispatch(
		compute_list,
		x_groups,
		y_groups,
		1
	)

	rd.compute_list_end()


func reload_shader() -> void:
	if rd == null:
		return

	if pipeline.is_valid():
		rd.free_rid(pipeline)

	if shader.is_valid():
		rd.free_rid(shader)

	shader = RID()
	pipeline = RID()


func set_camera_planes(
	new_near: float,
	new_far: float
) -> void:
	plane_mutex.lock()
	near_plane = max(new_near, 0.0001)
	far_plane = max(new_far, near_plane + 0.0001)
	plane_mutex.unlock()
