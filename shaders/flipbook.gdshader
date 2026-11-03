shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

// Plays a square flipbook sheet, blending between frames.
uniform sampler2D sheet : filter_linear_mipmap, repeat_disable;
uniform float progress = 0.0;
uniform float turn = 0.0;
uniform float brightness = 1.0;
uniform float opacity = 1.0;
uniform bool face_camera = true;
uniform vec2 grid = vec2(5.0);

vec4 frame(vec2 uv, float index) {
	vec2 cell = vec2(mod(index, grid.x), floor(index / grid.x));
	return texture(sheet, (cell + uv * 0.98 + 0.01) / grid);
}

void vertex() {
	if (face_camera) {
		float size = length(MODEL_MATRIX[0].xyz);
		mat4 facing = mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	}
	vec2 centred = UV - 0.5;
	float c = cos(turn);
	float s = sin(turn);
	UV = vec2(centred.x * c - centred.y * s, centred.x * s + centred.y * c) + 0.5;
}

void fragment() {
	float position = clamp(progress, 0.0, 1.0) * (grid.x * grid.y - 1.0);
	float first = floor(position);
	vec4 color = mix(frame(UV, first), frame(UV, min(first + 1.0, grid.x * grid.y - 1.0)), position - first);
	// The sheet holds display values; albedo is linear.
	ALBEDO = vec3(pow(color.r, 2.2)) * brightness;
	float inside = step(0.0, UV.x) * step(UV.x, 1.0) * step(0.0, UV.y) * step(UV.y, 1.0);
	ALPHA = color.a * opacity * inside;
}
