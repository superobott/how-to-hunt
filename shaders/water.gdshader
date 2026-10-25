shader_type spatial;
render_mode diffuse_burley;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float radius = length(p);
	float near_island = 1.0 - smoothstep(55.0, 135.0, radius);
	float swell = sin(p.x * 0.16 + p.y * 0.11 + TIME * 0.55);
	float ripples = sin(p.x * 1.05 - p.y * 0.56 + sin(p.y * 0.15) * 1.2 + TIME * 0.85);
	float glints = pow(max(0.0, sin(p.x * 0.42 + p.y * 0.32 + TIME * 0.31) * ripples), 12.0);
	vec3 deep = vec3(0.065, 0.27, 0.34);
	vec3 shallow = vec3(0.19, 0.48, 0.49);
	vec3 water = mix(deep, shallow, near_island * 0.8);
	water += swell * 0.012 + ripples * 0.009;
	ALBEDO = water + glints * vec3(0.13, 0.18, 0.17) * near_island;
	ROUGHNESS = 0.3;
	SPECULAR = 0.65;
}
