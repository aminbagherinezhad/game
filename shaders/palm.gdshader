shader_type spatial;
render_mode cull_disabled, specular_disabled;

// COLOR.r is the sway weight of a vertex.
uniform sampler2D frond : source_color, filter_linear_mipmap;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float phase = root.x * 0.31 + root.z * 0.23;
	float gust = sin(TIME * 0.5 + phase * 0.3);
	VERTEX.x += sin(TIME * 1.5 + phase) * COLOR.r * (0.3 + 0.2 * gust);
	VERTEX.z += cos(TIME * 1.15 + phase) * COLOR.r * 0.22;
}

void fragment() {
	vec4 leaf = texture(frond, UV);
	ALBEDO = leaf.rrr * 0.3;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
}
