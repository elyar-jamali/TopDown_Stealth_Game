#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Dedicated output texture. Only the R channel exists (R32F).
layout(
	r32f,
	set = 0,
	binding = 0
) uniform writeonly image2D depth_output;

// Resolved depth buffer produced by the guard camera.
layout(
	set = 0,
	binding = 1
) uniform sampler2D depth_texture;

layout(push_constant, std430) uniform Params {
	vec2 screen_size;
	float near_plane;
	float far_plane;
} params;


void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);

	if (
		pixel.x >= int(params.screen_size.x) ||
		pixel.y >= int(params.screen_size.y)
	) {
		return;
	}

	// Godot Forward+ uses reverse-Z:
	// raw depth = 1 at the near plane, 0 at the far plane.
	// texelFetch keeps the source and destination pixels exactly aligned.
	float raw_depth = texelFetch(
		depth_texture,
		pixel,
		0
	).r;

	// Convert reverse-Z perspective depth to linear view-space depth.
	float linear_depth =
		(
			params.near_plane *
			params.far_plane
		)
		/
		(
			params.near_plane
			+
			raw_depth *
			(
				params.far_plane -
				params.near_plane
			)
		);

	// Store normalized linear depth in [0, 1].
	// 0 ~= guard near plane, 1 = guard far plane / no opaque obstacle.
	float normalized_depth = clamp(
		linear_depth / params.far_plane,
		0.0,
		1.0
	);

	imageStore(
		depth_output,
		pixel,
		vec4(
			normalized_depth,
			0.0,
			0.0,
			1.0
		)
	);
}
