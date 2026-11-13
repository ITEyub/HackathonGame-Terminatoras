// Soft deep-water vignette over the 3D view (no screen texture needed).
shader_type canvas_item;

uniform vec3 tint : source_color = vec3(0.0, 0.08, 0.2);
uniform float strength = 0.5;
uniform float inner = 0.38;  // where the darkening starts (smaller = reaches further in)
uniform float outer = 0.85;  // where it reaches full strength
uniform float max_alpha = 0.92;

void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(inner, outer, length(uv * vec2(1.0, 0.85)));
	COLOR = vec4(tint, clamp(v * strength, 0.0, max_alpha));
}
