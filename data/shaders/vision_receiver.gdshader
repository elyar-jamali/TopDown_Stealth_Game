shader_type spatial;

render_mode
unshaded,
fog_disabled,
depth_draw_never,
cull_disabled,
blend_mix;

uniform sampler2D guard_depth_texture : filter_linear;
uniform sampler2D top_depth_texture : filter_nearest;

uniform mat4 guard_view_matrix;
uniform mat4 guard_projection_matrix;

uniform mat4 top_view_matrix;
uniform mat4 top_projection_matrix;

uniform float top_far_plane = 16.0;
uniform float top_near_plane = 0.05;
uniform float top_clearance_self_epsilon = 0.01;

uniform vec3 guard_world_position;
uniform vec3 guard_forward;

uniform float guard_view_distance = 10.0;
uniform float guard_horizontal_angle = 70.0;
uniform float guard_up_angle = 30.0;
uniform float guard_down_angle = 90.0;

uniform float guard_far_plane = 10.0;
uniform float guard_depth_bias = 0.003;

uniform vec4 vision_color : source_color =
vec4(0.15, 0.85, 0.25, 0.80);

uniform bool vision_enabled = false;

uniform float minimum_up_dot = 0.25;

/*
Temporary player sample heights.
Later these can be fed from the actual Player controller/collider.
*/
uniform float player_standing_height = 1.60;
uniform float player_crouch_height = 0.75;
uniform float player_feet_height = 0.03;

uniform float stripe_scale = 3.0;
uniform float stripe_alpha_multiplier = 0.38;

/*
Optional debug switches.
Keep both false for normal gameplay rendering.
*/
uniform bool debug_top_clearance = false;
uniform bool debug_visibility_classification = false;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (
		MODEL_MATRIX
		*
		vec4(
		VERTEX,
		1.0
		)
	).xyz;

	world_normal =
		normalize(
			MODEL_NORMAL_MATRIX
			*
			NORMAL
		);

}

/*
Guard depth visibility test.

This is the already-stable guard-depth test:

nearest sampling

base depth bias

local slope bias

far-distance bias
*/
bool is_point_visible_from_guard(vec3 test_world_position)
{
	vec4 test_view_position =
		guard_view_matrix *
		vec4(
			test_world_position,
			1.0
		);

	vec4 test_clip_position =
		guard_projection_matrix	* test_view_position;

	if (test_clip_position.w <= 0.0) {
		return false;
	}

	vec3 test_ndc =
		test_clip_position.xyz
		/
		test_clip_position.w;

	bool inside_depth_camera =
		test_ndc.x >= -1.0
		&& test_ndc.x <= 1.0
		&& test_ndc.y >= -1.0
		&& test_ndc.y <= 1.0
		&& test_ndc.z >= 0.0
		&& test_ndc.z <= 1.0;

	if (!inside_depth_camera) {
		return false;
	}

	vec2 test_uv = vec2(
		test_ndc.x * 0.5 + 0.5,
		1.0 - (test_ndc.y * 0.5 + 0.5)
	);
	//////////
	test_uv = clamp(
		test_uv,
		vec2(0.0),
		vec2(1.0)
	);

	float depth_center = texture(
		guard_depth_texture,
		test_uv
	).r;

	float point_depth =
		clamp(
			(-test_view_position.z) / guard_far_plane,
			0.0,
			1.0
		);

	ivec2 depth_size = textureSize(
		guard_depth_texture, 0
	);

	vec2 texel_size = 1.0 / vec2(depth_size);

	vec2 uv_min = texel_size * 0.5;

	vec2 uv_max = vec2(1.0) - uv_min;

	float depth_left = texture(
		guard_depth_texture, clamp(
			test_uv - vec2(texel_size.x, 0.0),
			uv_min,
			uv_max
		)
	).r;

	float depth_right =
	texture(
	guard_depth_texture,
	clamp(
	test_uv + vec2(texel_size.x, 0.0),
	uv_min,
	uv_max
	)
	).r;

	float depth_up =
	texture(
	guard_depth_texture,
	clamp(
	test_uv + vec2(0.0, texel_size.y),
	uv_min,
	uv_max
	)
	).r;

	float depth_down =
	texture(
	guard_depth_texture,
	clamp(
	test_uv - vec2(0.0, texel_size.y),
	uv_min,
	uv_max
	)
	).r;

	float depth_up_left =
	texture(
	guard_depth_texture,
	clamp(
	test_uv + vec2(-texel_size.x, texel_size.y),
	uv_min,
	uv_max
	)
	).r;

	float depth_up_right =
	texture(
	guard_depth_texture,
	clamp(
	test_uv + vec2(texel_size.x, texel_size.y),
	uv_min,
	uv_max
	)
	).r;

	float depth_down_left =
	texture(
	guard_depth_texture,
	clamp(
	test_uv + vec2(-texel_size.x, -texel_size.y),
	uv_min,
	uv_max
	)
	).r;

	float depth_down_right =
	texture(
	guard_depth_texture,
	clamp(
	test_uv + vec2(texel_size.x, -texel_size.y),
	uv_min,
	uv_max
	)
	).r;

	float depth_gradient_x =
	abs(depth_right - depth_left) * 0.5;

	float depth_gradient_y =
	abs(depth_up - depth_down) * 0.5;

	float local_depth_gradient =
	max(
	depth_gradient_x,
	depth_gradient_y
	);

	float neighborhood_max_depth =
	max(
	max(depth_center, depth_left),
	max(
	max(depth_right, depth_up),
	max(
	max(depth_down, depth_up_left),
	max(
	max(depth_up_right, depth_down_left),
	depth_down_right
	)
	)
	)
	);

	float slope_factor =
	smoothstep(
	0.002,
	0.02,
	local_depth_gradient
	);

	/*
	روی سطح صاف تقریباً همان depth مرکزی را نگه می‌داریم.
	روی سطح شیب‌دار یا لبه‌دار، کم‌کم به depth بیشینه‌ی همسایه‌ها
	اجازه می‌دهیم تا self-occlusion کمتر شود.
	*/
	float effective_obstacle_depth = depth_center;

	float slope_bias =
	min(
	local_depth_gradient * 1.0,
	0.005
	);

	float far_bias =
	smoothstep(
	0.65,
	1.0,
	point_depth
	) * 0.002;

	float depth_bias =
	guard_depth_bias
	+
	slope_bias
	+
	far_bias;

	bool same_surface = false;
	//abs(point_depth - effective_obstacle_depth) < 0.003;


	return (
	effective_obstacle_depth <= 0.000001
	||
	same_surface
	||
	point_depth <= effective_obstacle_depth + depth_bias
	);
}

/*
Top orthographic height/clearance test.

Return values:

approximately 0.0 : top camera sees this same receiver surface

positive value    : another surface is above this point

1000000.0+       : invalid/no top-depth sample

2000000.0+       : outside top-camera coverage/range
*/
float get_top_clearance(
vec3 test_world_position
) {
vec4 top_view_position =
top_view_matrix
*
vec4(
test_world_position,
1.0
);

vec4 top_clip_position =
top_projection_matrix
*
top_view_position;

if (
abs(top_clip_position.w)
<= 0.000001
) {
return 2000000.0;
}

vec3 top_ndc =
top_clip_position.xyz
/
top_clip_position.w;

/*
Only X/Y are used for the orthographic footprint.

Do not test top_ndc.z here.
The top camera's vertical range is tested in view space.
*/
if (
top_ndc.x < -1.0
|| top_ndc.x > 1.0
) {
return 2000000.0;
}

if (
top_ndc.y < -1.0
|| top_ndc.y > 1.0
) {
return 2000000.0;
}

float point_distance =
-top_view_position.z;

if (
point_distance < top_near_plane
||
point_distance > top_far_plane
) {
return 2000000.0;
}

vec2 top_uv = vec2(
top_ndc.x * 0.5 + 0.5,
1.0 - (
top_ndc.y * 0.5 + 0.5
)
);

float top_normalized_depth =
texture(
top_depth_texture,
top_uv
).r;

if (
top_normalized_depth
<= 0.000001
) {
return 1000000.0;
}

float top_surface_distance =
top_normalized_depth
*
top_far_plane;

return (
point_distance
-
top_surface_distance
);
}

void fragment() {

if (!vision_enabled) {
	discard;
}


/*
Only sufficiently upward-facing surfaces
can receive the FOV overlay.
*/
float up_dot =
	dot(
		normalize(world_normal),
		vec3(0.0, 1.0, 0.0)
	);


if (up_dot < minimum_up_dot) {
	discard;
}


/*
Horizontal gameplay FOV.
*/
vec3 to_point =
	world_position
	-
	guard_world_position;


/*
Asymmetric gameplay vertical FOV.

Positive angle = above the guard's eye horizon.
Negative angle = below the horizon.

Default gameplay limits:
+30 degrees upward
-90 degrees downward
*/
float horizontal_distance_3d =
	length(
		to_point.xz
	);


float vertical_angle_to_point =
	degrees(
		atan(
			to_point.y,
			max(
				horizontal_distance_3d,
				0.0001
			)
		)
	);


bool inside_vertical_fov =
	vertical_angle_to_point
		<= guard_up_angle
	&&
	vertical_angle_to_point
		>= -guard_down_angle;


if (!inside_vertical_fov) {
	discard;
}


to_point.y = 0.0;


vec3 horizontal_forward =
	guard_forward;


horizontal_forward.y = 0.0;


float distance_to_point =
	length(to_point);

bool inside_distance =
	distance_to_point
	<=
	guard_view_distance;


bool inside_angle = false;


if (
	distance_to_point > 0.0001
	&&
	length(horizontal_forward) > 0.0001
) {
	vec3 point_direction =
		normalize(to_point);


	vec3 forward_direction =
		normalize(horizontal_forward);


	float angle_cos =
		dot(
			forward_direction,
			point_direction
		);


	float minimum_cos =
		cos(
			radians(
				guard_horizontal_angle
				* 0.5
			)
		);


	inside_angle =
		angle_cos
		>=
		minimum_cos;
}


if (
	distance_to_point
	<= 0.0001
) {
	inside_angle = true;
}


bool inside_gameplay_fov =
	distance_to_point >= 0.05
	&&
	inside_distance
	&&
	inside_angle;


if (!inside_gameplay_fov) {
	discard;
}


/*
Top-camera local-overhead test.
*/
float top_clearance =
	get_top_clearance(
		world_position
	);


bool top_sample_valid =
	top_clearance
	<
	500000.0;


bool has_local_overhead =
	top_sample_valid
	&&
	top_clearance
	>
	top_clearance_self_epsilon;


/*
Player/body samples.

The important change in this clean version is that
we do not let one single low sample decide the result.

A visible low-body sample means crouching is NOT safe.
This also makes the visual field agree better with
multi-ray player detection near ramp edges.
*/
vec3 standing_point =
	world_position
	+
	vec3( 0.0, player_standing_height, 0.0);


vec3 crouch_point =
	world_position
	+
	vec3( 0.0, player_crouch_height, 0.0);

vec3 feet_point =
	world_position
	+
	vec3( 0.0, player_feet_height, 0.0);


/*
Near-surface visibility probe.

This is NOT a body sample. It answers one question only:
can the guard actually see this receiver surface?

Important:
move away from the receiver ALONG ITS SURFACE NORMAL,
not along world +Y.

On elevated/sloped receivers, a +Y offset can still land
behind the same surface at grazing view angles and create
false CROUCH_SAFE stripes. For flat ground, the normal is
already +Y, so the solved under-ramp behavior is unchanged.
*/
/*vec3 ground_probe_point =
	world_position
	+
	normalize(world_normal)
	*
	ground_probe_height;*/


bool standing_visible =
	is_point_visible_from_guard(
		standing_point
	);


bool crouch_visible_sample =
	is_point_visible_from_guard(
		crouch_point
	);

bool feet_visible =
	is_point_visible_from_guard(
		feet_point
	);
	

if (debug_visibility_classification)
{
if (feet_visible)
{
ALBEDO = vec3(1.0,0.0,0.0);
}
else
{
ALBEDO = vec3(0.0,0.0,1.0);
}

ALPHA = 1.0;

}

bool lower_body_visible =
	crouch_visible_sample
	||
	feet_visible;



bool any_body_visible =
	standing_visible
	||
	lower_body_visible;

bool usable_surface_visible =
	lower_body_visible;
/*
Debug mode 1:
top-camera classification only.
*/
if (debug_top_clearance) {

	if (
		top_clearance
		> 1500000.0
	) {
		ALBEDO =
			vec3(
				1.0,
				0.0,
				1.0
			);
	}
	else if (
		top_clearance
		> 500000.0
	) {
		ALBEDO =
			vec3(
				0.0,
				1.0,
				1.0
			);
	}
	else if (
		top_clearance
		<
		-top_clearance_self_epsilon
	) {
		ALBEDO =
			vec3(
				1.0,
				1.0,
				0.0
			);
	}
	else if (
		abs(top_clearance)
		<=
		top_clearance_self_epsilon
	) {
		ALBEDO =
			vec3(
				0.0,
				1.0,
				0.0
			);
	}
	else {
		ALBEDO =
			vec3(
				0.0,
				0.3,
				1.0
			);
	}


	ALPHA = 1.0;
}


/*
Debug mode 2:
final classification.

MAGENTA = local overhead and near-ground probe hidden
YELLOW  = no body sample visible
RED     = crouch-safe
BLUE    = full
*/
else if (
	debug_visibility_classification
) {

	if (
		has_local_overhead
		&&
		!feet_visible
	) {
		ALBEDO =
			vec3(
				1.0,
				0.0,
				1.0
			);
	}
	else if (
		!any_body_visible
	) {
		ALBEDO =
			vec3(
				1.0,
				1.0,
				0.0
			);
	}
	else if (
		!lower_body_visible
		&&
		standing_visible
	) {
		ALBEDO =
			vec3(
				1.0,
				0.0,
				0.0
			);
	}
	else {
		ALBEDO =
			vec3(
				0.0,
				0.35,
				1.0
			);
	}


	ALPHA = 1.0;
}


/*
Normal rendering.
*/
else {

	/*
	Important ramp rule:

	If another surface exists directly above this XZ
	AND a point just above the receiver surface cannot
	be seen by the guard, this receiver point is truly
	hidden under the ramp.

	Body samples are deliberately NOT used for this
	decision. They are used only for FULL/CROUCH_SAFE.
	*/
	if (
		has_local_overhead
		&&
		!feet_visible
	) {
		discard;
	}


	/*
	If no player sample is visible at all,
	the location is blocked.
	*/
	if (!any_body_visible) {
		discard;
	}


	/*
	FULL:
	At least one low-body/crouch sample is visible.
	Crouching would not hide the player.
	*/
	if (lower_body_visible) {
		ALBEDO =
			vision_color.rgb;
		ALPHA =
			vision_color.a;
	}


	/*
	CROUCH_SAFE:
	Standing/head sample is visible, but all
	lower-body samples are hidden.
	*/
	else {

		float stripe =
			step(
				0.5,
				fract(
					(
						world_position.x
						+
						world_position.z
					)
					*
					stripe_scale
				)
			);


		float alpha_factor =
			mix(
				stripe_alpha_multiplier,
				1.0,
				stripe
			);


		ALBEDO =
			vision_color.rgb;


		ALPHA =
			vision_color.a
			*
			alpha_factor;
	}
}

}