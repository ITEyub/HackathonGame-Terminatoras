// Room surfaces: flat colour (optional checker floor) + world-space caustics.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#include "res://shaders/caustics.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 albedo_b : source_color = vec3(1.0);
uniform bool checker = false;
uniform float caustic_strength = 0.2;
uniform vec3 caustic_color : source_color = vec3(0.65, 0.95, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo;
	if (checker) {
		vec2 cell = floor(wpos.xz);
		base = mix(albedo, albedo_b, mod(cell.x + cell.y, 2.0));
	}
	vec2 p = wpos.xz + vec2(wpos.y * 0.35, -wpos.y * 0.2);
	float cs = caustic_pattern(p * 0.9, TIME);
	ALBEDO = base;
	ROUGHNESS = 1.0;
	EMISSION = caustic_color * cs * caustic_strength;
}
