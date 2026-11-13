// Soap-bubble look: see-through centre, bright fresnel rim.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = vec3(0.85, 0.97, 1.0);
	ALPHA = 0.06 + f * 0.65;
}
