// Flat 2D characters in 3D: jelly wobble, light from above on the top edges, caustic shimmer.
#include "res://shaders/caustics.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float wobble = 0.03;
uniform float seed = 0.0;
uniform float caustic_strength = 0.07;
uniform float saturation = 1.3;
uniform vec3 rim_color : source_color = vec3(0.6, 0.9, 1.0);

varying vec3 wpos;

void vertex() {
	float h = 1.0 - UV.y;  // 0 at the feet, 1 at the top of the canvas
	VERTEX.x += sin(TIME * 3.0 + seed) * wobble * h * h;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	vec2 px = 3.0 / vec2(textureSize(tex, 0));
	float a = texture(tex, UV + vec2(px.x, 0.0)).a + texture(tex, UV - vec2(px.x, 0.0)).a
			+ texture(tex, UV + vec2(0.0, px.y)).a + texture(tex, UV - vec2(0.0, px.y)).a;
	float rim = 1.0 - a * 0.25;  // > 0 near the silhouette
	vec3 col = c.rgb;
	col += rim_color * rim * 0.3 * (1.0 - UV.y);
	col += vec3(0.6, 0.9, 1.0) * caustic_pattern(wpos.xy * 1.3 + vec2(wpos.z), TIME) * caustic_strength;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	ALBEDO = clamp(mix(vec3(luma), col, saturation), 0.0, 1.0);
}
