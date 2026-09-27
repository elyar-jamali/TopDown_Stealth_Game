extends Node

const ACTIVE_LAYER := 20
const PASSIVE_LAYER := 19

const MASK_SHADER := preload("res://data/shaders/outline_mask.gdshader")

var main_camera: Camera3D

var active_viewport: SubViewport
var active_camera: Camera3D

var passive_viewport: SubViewport
var passive_camera: Camera3D

var passive_reasons: Dictionary = {}
var active_targets: Dictionary = {}

var target_proxies: Dictionary = {}
var target_materials: Dictionary = {}


func register_renderers(
	camera: Camera3D,
	active_vp: SubViewport,
	active_cam: Camera3D,
	_active_rect: TextureRect,
	passive_vp: SubViewport,
	passive_cam: Camera3D,
	_passive_rect: TextureRect
) -> void:
	main_camera = camera

	active_viewport = active_vp
	active_camera = active_cam

	passive_viewport = passive_vp
	passive_camera = passive_cam


func _process(_delta: float) -> void:
	if main_camera == null:
		return

	var viewport_size := Vector2i(
		get_tree().root.get_visible_rect().size
	)

	if active_viewport != null:
		active_viewport.size = viewport_size

	if passive_viewport != null:
		passive_viewport.size = viewport_size

	_sync_camera(active_camera)
	_sync_camera(passive_camera)


func _sync_camera(camera: Camera3D) -> void:
	if camera == null:
		return

	camera.global_transform = main_camera.global_transform
	camera.projection = main_camera.projection
	camera.fov = main_camera.fov
	camera.size = main_camera.size
	camera.near = main_camera.near
	camera.far = main_camera.far


func set_active(
	target: Node,
	enable: bool,
	color: Color = Color.YELLOW
) -> void:
	if target == null:
		return

	var id := target.get_instance_id()

	if enable and not _can_highlight(target):
		enable = false

	if enable:
		_ensure_proxies(target, color)

		active_targets[id] = true

		_set_proxy_layer(
			id,
			PASSIVE_LAYER,
			false
		)

		_set_proxy_layer(
			id,
			ACTIVE_LAYER,
			true
		)

		_set_target_color(id, color)

	else:
		active_targets.erase(id)

		_set_proxy_layer(
			id,
			ACTIVE_LAYER,
			false
		)

		if passive_reasons.has(id):
			var reasons: Dictionary = passive_reasons[id]

			if not reasons.is_empty():
				_set_proxy_layer(
					id,
					PASSIVE_LAYER,
					true
				)


func set_passive(
	target: Node,
	reason: StringName,
	enable: bool,
	color: Color = Color.YELLOW
) -> void:
	if target == null:
		return

	var id := target.get_instance_id()

	if not passive_reasons.has(id):
		passive_reasons[id] = {}

	var reasons: Dictionary = passive_reasons[id]

	if enable and _can_highlight(target):
		reasons[reason] = true

		_ensure_proxies(target, color)
		_set_target_color(id, color)

	else:
		reasons.erase(reason)

	if reasons.is_empty():
		passive_reasons.erase(id)

		_set_proxy_layer(
			id,
			PASSIVE_LAYER,
			false
		)

		return

	passive_reasons[id] = reasons

	if not active_targets.has(id):
		_set_proxy_layer(
			id,
			PASSIVE_LAYER,
			true
		)


# Compatibility with existing hover code.
func set_target(
	target: Node,
	enable: bool,
	color: Color = Color.YELLOW
) -> void:
	set_active(target, enable, color)


func clear_passive_reason(
	reason: StringName
) -> void:
	var ids := passive_reasons.keys()

	for id in ids:
		var target := instance_from_id(id)

		if target == null:
			passive_reasons.erase(id)
			continue

		var color := Color.YELLOW

		if target.has_method("get_outline_color"):
			color = target.get_outline_color()
		elif "outline_color" in target:
			color = target.outline_color

		set_passive(
			target,
			reason,
			false,
			color
		)


func _can_highlight(target: Node) -> bool:
	if "highlightable" in target:
		return target.highlightable

	return true


func _ensure_proxies(
	target: Node,
	color: Color
) -> void:
	var id := target.get_instance_id()

	if target_proxies.has(id):
		_set_target_color(id, color)
		return

	var proxies: Array[MeshInstance3D] = []

	var material := ShaderMaterial.new()
	material.shader = MASK_SHADER

	material.set_shader_parameter(
		"mask_color",
		color
	)

	target_materials[id] = material

	_create_proxies_recursive(
		target,
		proxies,
		material
	)

	target_proxies[id] = proxies


func _create_proxies_recursive(
	node: Node,
	proxies: Array[MeshInstance3D],
	material: ShaderMaterial
) -> void:
	if node.has_meta("_exclude_from_outline"):
		return
	if node is MeshInstance3D:
		var source := node as MeshInstance3D
		if source.get_layer_mask_value(17):
			return
		if source.has_meta("_outline_proxy"):
			return

		var proxy := MeshInstance3D.new()

		proxy.set_meta(
			"_outline_proxy",
			true
		)

		proxy.mesh = source.mesh
		proxy.skin = source.skin
		proxy.transform = Transform3D.IDENTITY
		proxy.material_override = material

		proxy.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)

		proxy.layers = 0

		source.add_child(proxy)

		if source.skeleton != NodePath():
			var skeleton := source.get_node_or_null(
				source.skeleton
			)

			if skeleton != null:
				proxy.skeleton = proxy.get_path_to(
					skeleton
				)

		proxies.append(proxy)

	for child in node.get_children():
		if child.has_meta("_outline_proxy"):
			continue

		_create_proxies_recursive(
			child,
			proxies,
			material
		)


func _set_proxy_layer(
	id: int,
	layer: int,
	enable: bool
) -> void:
	if not target_proxies.has(id):
		return

	var proxies: Array = target_proxies[id]

	for proxy in proxies:
		if not is_instance_valid(proxy):
			continue

		proxy.set_layer_mask_value(
			layer,
			enable
		)


func _set_target_color(
	id: int,
	color: Color
) -> void:
	if not target_materials.has(id):
		return

	var material: ShaderMaterial = target_materials[id]

	material.set_shader_parameter(
		"mask_color",
		color
	)
