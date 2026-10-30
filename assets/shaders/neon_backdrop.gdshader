shader_type spatial;
render_mode unshaded;

uniform float motion_time = 0.0;
uniform float effect_strength = 1.0;
varying vec2 world_xy;

void vertex() {
	world_xy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xy;
}

void fragment() {
	vec2 p = world_xy;
	float t = motion_time;
	vec3 cyan = vec3(0.0, 0.65, 0.85);
	vec3 pink = vec3(0.7, 0.015, 0.35);
	vec3 violet = vec3(0.22, 0.035, 0.6);
	vec3 color = vec3(0.006, 0.002, 0.023);

	// Repeated stage lights cover the whole climbing course in one opaque draw.
	vec2 stage = mod(p + vec2(30.0, 20.0), vec2(60.0, 40.0)) - vec2(30.0, 20.0);
	vec3 lights = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float phase = float(i) * 1.7;
		float angle = 0.35 * sin(t * 0.24 + phase) + (float(i) - 1.0) * 0.5;
		float beam = abs(stage.x * cos(angle) - stage.y * sin(angle));
		float fade = (1.0 - smoothstep(13.0, 20.0, abs(stage.y)))
			* (1.0 - smoothstep(22.0, 30.0, abs(stage.x)));
		vec3 tint = mix(cyan, pink, float(i) * 0.5);
		lights += tint * (0.32 * exp(-beam * 22.0) + 0.045 * exp(-beam * 1.6)) * fade;
	}

	for (int i = 0; i < 2; i++) {
		float lane = float(i);
		float wave = 4.5 * sin(p.x * 0.085 + t * 0.22 + lane * 2.6)
			+ 1.5 * sin(p.x * 0.18 - t * 0.17 + lane);
		float ribbon = abs(mod(p.y - wave + lane * 11.0 + 14.0, 28.0) - 14.0);
		float body = 1.0 - smoothstep(0.18, 0.65, ribbon);
		float edge = exp(-abs(ribbon - 0.35) * 12.0);
		float halo = exp(-ribbon * 0.75);
		vec3 tint = mix(violet, pink, lane);
		lights += tint * (body * 0.11 + edge * 0.25 + halo * 0.035);
	}
	ALBEDO = color + lights * effect_strength;
}
