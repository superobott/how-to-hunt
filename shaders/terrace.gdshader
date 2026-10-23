shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 meadow_color : source_color = vec4(0.36, 0.62, 0.30, 1.0);
uniform vec4 cliff_color : source_color = vec4(0.55, 0.47, 0.35, 1.0);
uniform float half_height = 3.0;
varying vec3 local_normal;
varying vec3 local_position;

void vertex() {
	local_normal = NORMAL;
	local_position = VERTEX;
}

void fragment() {
	float grass = smoothstep(0.35, 0.8, local_normal.y);
	float edge_moss = smoothstep(half_height - 0.5, half_height, local_position.y) * 0.35;
	float strata = sin(local_position.y * 3.2 + sin(local_position.x * 0.3)) * 0.025;
	ALBEDO = mix(cliff_color.rgb + vec3(strata), meadow_color.rgb, max(grass, edge_moss));
	ROUGHNESS = 1.0;
}
