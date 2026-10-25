shader_type sky;

uniform vec3 zenith : source_color = vec3(0.20, 0.49, 0.67);
uniform vec3 horizon : source_color = vec3(0.83, 0.88, 0.77);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.96, 0.83);
uniform vec3 cloud_shade : source_color = vec3(0.73, 0.79, 0.78);

float hash_cloud(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_cloud(cell), hash_cloud(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_cloud(cell + vec2(0.0, 1.0)), hash_cloud(cell + vec2(1.0)), f.x), f.y);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float altitude = max(direction.y, 0.0);
	vec3 color = mix(horizon, zenith, pow(altitude, 0.55));
	if (direction.y > 0.02) {
		vec2 plane = direction.xz / (direction.y + 0.24) * 1.7;
		float cloud = cloud_noise(plane) * 0.68 + cloud_noise(plane * 2.3 + 6.0) * 0.32;
		float puffs = smoothstep(0.53, 0.68, cloud);
		puffs *= smoothstep(0.02, 0.20, direction.y) * (1.0 - smoothstep(0.72, 0.97, direction.y));
		color = mix(color, mix(cloud_shade, cloud_light, smoothstep(0.54, 0.74, cloud)), puffs * 0.90);
	}
	vec3 sun_direction = normalize(vec3(-0.48, 0.57, 0.67));
	float sun = max(dot(direction, sun_direction), 0.0);
	color += vec3(1.0, 0.75, 0.38) * pow(sun, 18.0) * 0.10;
	color = mix(color, vec3(1.0, 0.95, 0.77), smoothstep(0.9994, 0.9998, sun));
	COLOR = color;
}
