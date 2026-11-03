shader_type spatial;
render_mode specular_disabled;

// Aerial map built by tools/generate_textures.py; covers 240 x 240 metres.
uniform sampler2D ground_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;

const float MAP_SIZE = 240.0;

varying vec3 world_pos;

// Keep the shoreline in sync with tools/generate_textures.py.
float shore_distance(vec2 p) {
	return p.x + 12.0 * sin(p.y * 0.045) + 6.0 * sin(p.y * 0.13 + 1.0) - 70.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float map = texture(ground_map, p / MAP_SIZE + 0.5).r;
	float detail = texture(detail_map, p * 0.11).r;
	vec3 color = vec3(map * (0.68 + detail * 0.5));
	float wet = 0.0;

	// Water is only worked out near and past the shoreline.
	float shore = shore_distance(p);
	if (shore > -6.0) {
		float swell = texture(detail_map, p * 0.012 + vec2(TIME * 0.002, TIME * 0.0012)).r;
		shore += (swell - 0.5) * 8.0;
		float ripple = texture(detail_map, p * 0.05 + vec2(TIME * 0.012, TIME * 0.007)).r;
		float foam = sin(shore * 1.5 - TIME * 0.9 + ripple * 8.0) * 0.5 + 0.5;
		foam *= 1.0 - smoothstep(0.0, 5.0, shore);
		vec3 water = vec3(0.02 + 0.1 * ripple) + vec3(0.5) * foam * foam * foam * foam;
		wet = smoothstep(-0.4, 0.6, shore);
		color = mix(color, water, wet);
	}

	float cloud = texture(detail_map, p * 0.0028 + vec2(TIME * 0.0035, TIME * 0.0016)).r;
	color *= 1.0 - 0.3 * smoothstep(0.42, 0.6, cloud);

	ALBEDO = color;
	NORMAL_MAP = texture(detail_normal, p * 0.11).xyz;
	NORMAL_MAP_DEPTH = 1.4 * (1.0 - wet);
	ROUGHNESS = mix(0.95, 0.3, wet);
}
