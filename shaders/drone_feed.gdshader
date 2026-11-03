shader_type canvas_item;

// White-hot thermal camera: soft optics, heavy bloom and a flash that burns the sensor.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec3 tint = vec3(0.95, 0.97, 0.97);
uniform float contrast = 1.55;
uniform float softness = 0.75;
uniform float bloom_threshold = 0.74;
uniform float bloom_strength = 1.0;
uniform float scanline_strength = 0.05;
uniform float grain_strength = 0.03;
// Set by battlefield.gd for a moment after every explosion.
uniform float flash = 0.0;
// The blast wave: a thin ring that bends the picture as it passes.
uniform vec2 shock_centre = vec2(0.5);
uniform float shock_radius = 0.0;
uniform float shock_strength = 0.0;

float luma(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

float bright(vec2 uv, float lod) {
	return max(luma(textureLod(screen_texture, uv, lod).rgb) - bloom_threshold, 0.0);
}

float random(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (shock_strength > 0.001) {
		float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 away = (uv - shock_centre) * vec2(aspect, 1.0);
		float reach = length(away);
		float ring = exp(-pow((reach - shock_radius) / 0.02, 2.0));
		uv -= away / (reach + 0.001) * ring * shock_strength * vec2(1.0 / aspect, 1.0);
	}

	float value = luma(textureLod(screen_texture, uv, softness).rgb);
	value = clamp((value - 0.42) * contrast + 0.46, 0.0, 1.0);

	float bloom = bright(uv, 2.0) * 0.5 + bright(uv, 3.5) * 0.8 + bright(uv, 5.0) * 1.1;
	value += bloom * bloom_strength * (1.0 + flash * 2.0);
	value = mix(clamp(value, 0.0, 1.0), 1.0, flash);

	vec3 color = tint * value;
	color *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(FRAGCOORD.y * 1.9));
	color += (random(SCREEN_UV + fract(TIME)) - 0.5) * grain_strength;

	vec2 centered = SCREEN_UV - 0.5;
	float vignette = 1.0 - smoothstep(0.34, 0.85, length(centered * vec2(1.0, 1.2)));
	color *= mix(0.5, 1.0, vignette);

	COLOR = vec4(color, 1.0);
}
