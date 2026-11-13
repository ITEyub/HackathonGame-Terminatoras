// Additive sun shaft / heaven beam. UV.y = 0 at the top (bright), fades downwards.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(0.55, 0.9, 1.0);
uniform float strength = 0.18;
uniform float speed = 1.0;
uniform bool soft_edges = true;

void fragment() {
	float edge = soft_edges ? smoothstep(0.0, 0.35, UV.x) * smoothstep(1.0, 0.65, UV.x) : 1.0;
	float fade = pow(1.0 - UV.y, 1.4);
	float flick = 0.75 + 0.25 * sin(TIME * speed + UV.x * 7.0);
	ALBEDO = color;
	ALPHA = strength * edge * fade * flick;
}
