shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec4 base_color : source_color = vec4(0.6, 0.7, 0.4, 1.0);
uniform float sway_strength = 0.04;
varying float clump_shade;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.34 + world.z * 0.26 + INSTANCE_CUSTOM.x * 6.28318;
	float sway = sin(TIME * 1.5 + phase) + sin(TIME * 2.1 + phase * 0.7) * 0.35;
	float flex = clamp(VERTEX.y * 3.0, 0.0, 1.0);
	VERTEX.x += sway * sway_strength * flex;
	VERTEX.z += sway * sway_strength * flex * 0.4;
	clump_shade = mix(0.82, 1.08, INSTANCE_CUSTOM.y);
}

void fragment() {
	// Small crossed blades use a painted light ramp instead of unstable back-face shadows.
	ALBEDO = base_color.rgb * COLOR.rgb * clump_shade * 1.1;
	ROUGHNESS = 1.0;
}
