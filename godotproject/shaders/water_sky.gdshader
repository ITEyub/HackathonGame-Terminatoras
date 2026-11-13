// Underwater sky dome: dark depths below, bright rippling surface above.
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

#include "res://shaders/caustics.gdshaderinc"

uniform vec3 top_color : source_color = vec3(0.6, 0.92, 1.0);
uniform vec3 mid_color : source_color = vec3(0.22, 0.5, 0.65);
uniform vec3 bottom_color : source_color = vec3(0.03, 0.12, 0.25);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float y = dir.y;
	vec3 c = y > 0.0 ? mix(mid_color, top_color, pow(y, 0.8)) : mix(mid_color, bottom_color, pow(-y, 0.6));
	if (y > 0.15) {
		c += vec3(0.8, 1.0, 1.0) * caustic_pattern(dir.xz / (y + 0.3) * 5.0, TIME * 0.6) * 0.4 * y;
	}
	ALBEDO = c;
}
