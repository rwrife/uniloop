shader_type spatial;
render_mode unshaded;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = fract(world_pos.xy / 18.0);
	vec2 broad = step(vec2(0.30), p) * step(p, vec2(0.66));
	vec2 fine = step(vec2(0.80), p) * step(p, vec2(0.85));
	vec2 thread = step(vec2(0.96), fract(world_pos.xy * 2.0));
	float gray = 0.18 - 0.03 * (broad.x + broad.y)
		- 0.018 * (fine.x + fine.y) + 0.006 * (thread.x + thread.y);
	ALBEDO = vec3(pow(gray, 2.2));
}
