shader_type spatial;
render_mode unshaded;

void fragment() {
	// Fine luminous seams give the stripes a textured, LED-panel finish.
	vec2 panel = abs(fract(UV * vec2(12.0, 4.0)) - 0.5);
	float seam = smoothstep(0.43, 0.49, max(panel.x, panel.y));
	ALBEDO = COLOR.rgb * mix(0.78, 1.0, seam);
	EMISSION = COLOR.rgb * mix(0.35, 0.7, seam);
}
