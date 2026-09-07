shader_type spatial;

render_mode unshaded, shadows_disabled;

uniform vec4 mask_color : source_color = vec4(1.0, 0.8, 0.1, 1.0);

void fragment() {
	ALBEDO = mask_color.rgb;
	ALPHA = mask_color.a;
}