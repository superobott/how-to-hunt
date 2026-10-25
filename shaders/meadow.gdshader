shader_type spatial;
render_mode diffuse_burley;

uniform vec4 meadow_color : source_color = vec4(0.39, 0.57, 0.26, 1.0);
uniform float tier_radius = 60.0;
uniform float terrace_index = 0.0;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), blend.x), blend.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float broad = noise(p * 0.115);
	float tufts = noise(p * 1.2 + vec2(17.8));
	vec3 grass = meadow_color.rgb * mix(0.79, 1.13, broad);
	grass = mix(grass, vec3(0.55, 0.57, 0.29), smoothstep(0.49, 0.82, broad) * 0.44);
	grass *= 0.94 + tufts * 0.12;
	float radial = length(p);
	float angle = atan(p.y, p.x);
	float trail_center = 48.2 + sin(angle * 3.0 + 0.3) * 1.4;
	float trail_distance = abs(radial - trail_center);
	float trail = 1.0 - smoothstep(0.70, 1.58, trail_distance + (tufts - 0.5) * 0.4);
	// A worn clearing joins the first trail to the tent, spawn and trader.
	float clearing = 1.0 - smoothstep(0.72, 1.12, length((p - vec2(2.0, 51.0)) / vec2(11.0, 4.0)));
	float dirt = max(trail * 0.91, clearing * 0.9) * (1.0 - step(0.5, terrace_index));
	vec3 earth = mix(vec3(0.47, 0.37, 0.23), vec3(0.62, 0.50, 0.32), noise(p * 0.83));
	float pebbles = step(0.94, hash(floor(p * 10.0))) * 0.065;
	vec3 color = mix(grass, earth + pebbles, dirt);
	float rim = smoothstep(tier_radius - 0.7, tier_radius - 0.07, radial);
	color = mix(color, vec3(0.52, 0.50, 0.34), rim * 0.61);
	float flecks = hash(floor(p * 34.0));
	ALBEDO = color + (flecks - 0.5) * 0.022;
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
