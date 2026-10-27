extends Node3D
class_name PistolAimPreview

# Pistol target ray remains unchanged; range contours are now GPU-rendered spheres.
const GROUND_MASK: int = 1 << 6  # Physics layer 7
const RAGDOLL_MASK: int = 1 << 7 # Physics layer 8
const SPHERE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;

uniform vec4 tint : source_color = vec4(0.0, 0.8, 0.1, 1.0);
//ُ sphere opacity 0 = can not seen
uniform float base_alpha : hint_range(0.0, 1.0) = 0.0;
// edge opacity
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.55;
//edge width
uniform float edge_width : hint_range(0.01, 3.0) = 0.34;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	float edge = 0.0;
	if (depth < 0.99999) {
		// Reconstruct visible scene position in camera/view coordinates.
		vec4 view_point = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		view_point.xyz /= view_point.w;
		float separation = distance(view_point.xyz, VERTEX);
		edge = 1.0 - smoothstep(0.0, edge_width, separation);
	}
	ALBEDO = tint.rgb;
	ALPHA = max(base_alpha, edge * edge_alpha) * tint.a;
}
"""

var aim_mesh := ImmediateMesh.new()
var aim_instance := MeshInstance3D.new()
var range_sphere := MeshInstance3D.new()
var sound_sphere := MeshInstance3D.new()
var last_weapon_range := -1.0
var last_sound_range := -1.0
#shooting line colors
var good_material := _make_material(GameColors.get_color(GameColors.Preset.GREEN))
var bad_material := _make_material(GameColors.get_color(GameColors.Preset.RED))

func _ready() -> void:
	add_child(aim_instance)
	aim_instance.top_level = true
	aim_instance.mesh = aim_mesh
	aim_instance.set_layer_mask_value(1, false)
	aim_instance.set_layer_mask_value(18, true)

	#sphere colors
	_setup_sphere(range_sphere, GameColors.Preset.ORANGE)
	_setup_sphere(sound_sphere, GameColors.Preset.YELLOW)

	clear()

func _setup_sphere(instance: MeshInstance3D, preset: GameColors.Preset) -> void:
	add_child(instance)
	instance.top_level = true
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	instance.mesh = sphere
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SPHERE_SHADER_CODE
	material.shader = shader
	material.set_shader_parameter("tint", GameColors.get_color(preset))
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_layer_mask_value(1, true)

func clear() -> void:
	aim_mesh.clear_surfaces()
	range_sphere.visible = false
	sound_sphere.visible = false

func update_preview(camera: Camera3D, mouse: Vector2, player: CharacterBody3D,
		muzzle: Marker3D, weapon_range: float, sound_range: float, hovered_target: Node3D = null) -> Vector3:
	aim_mesh.clear_surfaces()
	if camera == null or muzzle == null:
		range_sphere.visible = false
		sound_sphere.visible = false
		return Vector3.ZERO

	var center := player.global_position + Vector3.UP * 0.85
	range_sphere.global_position = center
	sound_sphere.global_position = center
	if weapon_range != last_weapon_range:
		range_sphere.scale = Vector3.ONE * maxf(weapon_range, 0.01)
		last_weapon_range = weapon_range
	if sound_range != last_sound_range:
		sound_sphere.scale = Vector3.ONE * maxf(sound_range, 0.01)
		last_sound_range = sound_range
	range_sphere.visible = weapon_range > 0.0
	sound_sphere.visible = sound_range > 0.0

	var space := get_world_3d().direct_space_state
	var ray_start := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var camera_ray := PhysicsRayQueryParameters3D.create(
		ray_start, ray_start + ray_direction * 2000.0, GROUND_MASK)
	camera_ray.exclude = [player.get_rid()]
	var ground_hit := space.intersect_ray(camera_ray)
	var target: Vector3

	if not ground_hit.is_empty():
		target = ground_hit.position
	else:
		var plane := Plane(Vector3.UP, player.global_position.y)
		var fallback = plane.intersects_ray(ray_start, ray_direction)
		if fallback == null:
			return Vector3.ZERO
		target = fallback

	if is_instance_valid(hovered_target):
		target = hovered_target.global_position + Vector3.UP * 1.0

	var muzzle_position := muzzle.global_position
	var target_distance := muzzle_position.distance_to(target)
	var within_range := target_distance <= weapon_range
	var end_point := target
	# if target_distance > weapon_range:
	#	 end_point = muzzle_position + (target - muzzle_position).normalized() * weapon_range

	var obstruction := PhysicsRayQueryParameters3D.create(
		muzzle_position, end_point, 0xFFFFFFFF & ~RAGDOLL_MASK)
	obstruction.exclude = [player.get_rid()]
	var hit := space.intersect_ray(obstruction)
	var blocked := false

	if not hit.is_empty():
		var hit_is_target : bool = (
			is_instance_valid(hovered_target)
			and hit.collider == hovered_target
		)

		blocked = not hit_is_target and hit.position.distance_to(end_point) > 0.12

		if blocked or hit_is_target:
			end_point = hit.position

	_draw_line(muzzle_position, end_point,
		good_material if within_range and not blocked else bad_material)
	return target

func _draw_line(a: Vector3, b: Vector3, material: Material) -> void:
	aim_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	aim_mesh.surface_add_vertex(a)
	aim_mesh.surface_add_vertex(b)
	aim_mesh.surface_end()

static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = false
	return material
