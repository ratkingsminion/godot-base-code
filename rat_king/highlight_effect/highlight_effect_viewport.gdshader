shader_type spatial;
render_mode cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).r - 0.00001;
	ALBEDO = vec3(floor(depth * 2048.0), fract(depth * 2048.0), 0.0);
}
