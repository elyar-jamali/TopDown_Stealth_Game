shader_type canvas_item;

uniform vec2 control_size = vec2(120.0, 120.0);
uniform float corner_radius_px = 45.0;
uniform float border_width_px = 5.0;
uniform bool corner_on_left = false;

uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.29);

bool inside_shape(vec2 p, float inset) {
	float left = inset;
	float top = inset;
	float right = control_size.x - inset;
	float bottom = control_size.y - inset;

	if (p.x < left || p.y < top || p.x > right || p.y > bottom) {
		return false;
	}

	float radius = max(corner_radius_px - inset, 0.0);
	vec2 corner_center = vec2(0.0);

	if (corner_on_left) {
		corner_center = vec2(
			corner_radius_px,
			control_size.y - corner_radius_px
		);

		if (p.x < corner_center.x && p.y > corner_center.y) {
			if (distance(p, corner_center) > radius) {
				return false;
			}
		}
	} else {
		corner_center = vec2(
			control_size.x - corner_radius_px,
			control_size.y - corner_radius_px
		);

		if (p.x > corner_center.x && p.y > corner_center.y) {
			if (distance(p, corner_center) > radius) {
				return false;
			}
		}
	}

	return true;
}

void fragment() {
	vec2 p = UV * control_size;

	bool outer = inside_shape(p, 0.0);
	if (!outer) {
		discard;
	}

	bool inner = inside_shape(p, border_width_px);

	if (!inner) {
		COLOR = border_color;
	} else {
		COLOR = texture(TEXTURE, UV);
	}
}