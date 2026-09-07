shader_type canvas_item;

uniform float outline_width : hint_range(1.0, 6.0, 1.0) = 2.0;

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;

	vec4 center = texture(TEXTURE, UV);
	vec4 best = vec4(0.0);

	vec4 s;

	s = texture(TEXTURE, UV + vec2( pixel.x, 0.0));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2(-pixel.x, 0.0));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2(0.0,  pixel.y));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2(0.0, -pixel.y));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2( pixel.x,  pixel.y));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2(-pixel.x,  pixel.y));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2( pixel.x, -pixel.y));
	if (s.a > best.a) best = s;

	s = texture(TEXTURE, UV + vec2(-pixel.x, -pixel.y));
	if (s.a > best.a) best = s;

	float outline = best.a * (1.0 - center.a);

	COLOR = vec4(best.rgb, outline);
}