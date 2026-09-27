#[compute]
#version 450


layout(
	local_size_x = 8,
	local_size_y = 8,
	local_size_z = 1
) in;


layout(
	r32f,
	set = 0,
	binding = 0
) uniform image2D output_image;


layout(
	set = 0,
	binding = 1
) uniform sampler2D depth_texture;


layout(
	push_constant,
	std430
) uniform Params {
	vec2 screen_size;
	float near_plane;
	float far_plane;
} params;


void main() {
	ivec2 pixel =
		ivec2(
			gl_GlobalInvocationID.xy
		);


	if (
		pixel.x >= int(params.screen_size.x)
		||
		pixel.y >= int(params.screen_size.y)
	) {
		return;
	}


	vec2 uv =
		(
			vec2(pixel)
			+ vec2(0.5)
		)
		/
		params.screen_size;


	float raw_depth =
		texture(
			depth_texture,
			uv
		).r;


	/*
	Godot uses reverse-Z.

	0 means far/background,
	1 means near.
	*/

	if (raw_depth <= 0.000001) {
		imageStore(
			output_image,
			pixel,
			vec4(
				0.0,
				0.0,
				0.0,
				1.0
			)
		);

		return;
	}


	/*
	Orthographic depth is linear.

	raw = 1 → near
	raw = 0 → far
	*/
	float linear_depth =
		mix(
			params.far_plane,
			params.near_plane,
			raw_depth
		);


	float normalized_depth =
		clamp(
			linear_depth
			/
			params.far_plane,
			0.0,
			1.0
		);


	imageStore(
		output_image,
		pixel,
		vec4(
			normalized_depth,
			0.0,
			0.0,
			1.0
		)
	);
}