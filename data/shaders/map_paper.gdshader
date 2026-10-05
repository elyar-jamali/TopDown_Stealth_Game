shader_type canvas_item;

uniform vec4 paper_color : source_color = vec4(0.89, 0.86, 0.75, 1.0);
uniform float saturation : hint_range(0.0, 1.0) = 0.03;
uniform float contrast : hint_range(0.5, 2.0) = 1.10;
uniform float edge_strength : hint_range(0.0, 2.0) = 0.32;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.38;
uniform float light_floor : hint_range(0.0, 1.0) = 0.28;
uniform float posterize_levels : hint_range(2.0, 16.0) = 8.0;

float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float center = luminance(source.rgb);
	float left = luminance(texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).rgb);
	float right = luminance(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).rgb);
	float up = luminance(texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).rgb);
	float down = luminance(texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).rgb);
	float edge = length(vec2(right - left, down - up));

	float value = max(center, light_floor);
	value = (value - 0.5) * contrast + 0.5;
	value = clamp(value, 0.0, 1.0);
	value = floor(value * posterize_levels) / posterize_levels;

	float ink = 1.0 - value;
	vec3 paper_map = paper_color.rgb - vec3(ink * ink_strength);
	vec3 source_tint = mix(vec3(center), source.rgb, saturation) * paper_color.rgb;
	vec3 map_color = mix(paper_map, source_tint, saturation);
	map_color -= edge * edge_strength;

	COLOR = vec4(clamp(map_color, 0.0, 1.0), source.a);
}