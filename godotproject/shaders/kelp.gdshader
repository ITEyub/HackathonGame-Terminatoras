// Kelp / sea grass swaying in the current (vertex sway, stronger towards the tip).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;

uniform vec3 albedo : source_color = vec3(0.25, 0.6, 0.3);
uniform float height = 3.0;
uniform float sway = 0.35;

varying float tip;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	tip = clamp((VERTEX.y + height * 0.5) / height, 0.0, 1.0);
	float bend = tip * tip * sway * height * 0.3;
	VERTEX.x += sin(TIME * 1.3 + w.x * 0.7 + w.z * 0.4) * bend;
	VERTEX.z += cos(TIME * 1.1 + w.z * 0.6) * bend * 0.6;
}

void fragment() {
	ALBEDO = mix(albedo * 0.45, albedo * 1.15, tip);
	ROUGHNESS = 1.0;
}
