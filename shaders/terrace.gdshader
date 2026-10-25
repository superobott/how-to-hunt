shader_type spatial;
render_mode diffuse_burley;

uniform vec4 meadow_color : source_color = vec4(0.39, 0.57, 0.26, 1.0);
uniform vec4 cliff_color : source_color = vec4(0.57, 0.52, 0.43, 1.0);
uniform float tier_top = 7.0;
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
	// Angular coordinates keep sediment continuous around the whole mountain.
	vec2 rock = vec2(atan(world_position.z, world_position.x) * 24.0, world_position.y);
	float weather = noise(rock * vec2(0.36, 0.48));
	float sediment = rock.y * 0.68 + noise(rock * vec2(0.22, 0.14)) * 0.46;
	float seam = 1.0 - smoothstep(0.025, 0.115, fract(sediment));
	float layer = floor(sediment);
	float layer_tone = hash(vec2(layer, 4.7));
	vec3 sandstone = cliff_color.rgb * mix(0.83, 1.17, layer_tone);
	vec3 gray_stone = vec3(0.43, 0.47, 0.44);
	vec3 stone = mix(sandstone, gray_stone, smoothstep(0.42, 0.86, weather) * 0.46);
	float crack_line = abs(sin(rock.x * 1.6 + noise(vec2(rock.y * 0.38, rock.x * 0.07)) * 2.4));
	float cracks = (1.0 - smoothstep(0.015, 0.055, crack_line)) * smoothstep(0.32, 0.7, weather);
	stone *= 1.0 - seam * 0.24 - cracks * 0.24;
	float top_moss = (1.0 - smoothstep(0.12, 1.7, tier_top - world_position.y)) * smoothstep(0.2, 0.73, weather);
	stone = mix(stone, meadow_color.rgb * 0.72, top_moss * 0.7);
	float grit = hash(floor(rock * 30.0));
	ALBEDO = stone * COLOR.rgb + (grit - 0.5) * 0.022;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
