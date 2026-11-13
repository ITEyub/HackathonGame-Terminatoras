// Cheap animated underwater caustics (a few layered sines). Works on every renderer.
float caustic_pattern(vec2 p, float t) {
	vec2 q = p;
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		q += vec2(sin(q.y * 1.7 + t * 0.9 + fi), cos(q.x * 1.5 - t * 0.7 + fi * 1.3)) * 0.45;
		c += abs(sin(q.x * 2.1 + q.y * 1.9));
	}
	return pow(1.0 - c / 3.0, 4.0);
}
