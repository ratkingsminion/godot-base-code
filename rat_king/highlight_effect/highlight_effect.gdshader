shader_type spatial;
render_mode cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform int width_outline = 1;
uniform vec4 color_inner : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform vec4 color_outline : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D highlighted_depth_tex : repeat_disable;

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

float unpack_float(sampler2D tex, vec2 uv) {
	vec4 t = texture(tex, uv);
	return t.x / 2048.0 + t.y / 2048.0;
}

void fragment() {
	vec2 suv = SCREEN_UV;
	float d = texture(depth_tex, suv).r;
	float d_h = unpack_float(highlighted_depth_tex, suv);
	vec4 ss = texture(screen_tex, suv);
	
	bool is_inner = d > d_h && ss.a > 0.0;
	bool is_outline = false; // = n > 0.0 && !is_inner;
	
	if (!is_inner) {
	vec2 p = 1.0 / vec2(VIEWPORT_SIZE.xy);
		for (int x = -width_outline; x <= width_outline && !is_outline; ++x) {
			for (int y = -width_outline; y <= width_outline && !is_outline; ++y) {
				if (y == 0 && x == 0) { continue; }
				vec2 n_uv = suv + vec2(-p.x * float(x), -p.y * float(y));
				float n_ss_a = texture(screen_tex, n_uv).a;
				if (n_ss_a > 0.0) {
					float n_d = texture(depth_tex, n_uv).r;
					float n_d_h = unpack_float(highlighted_depth_tex, n_uv);
					is_outline = n_d > n_d_h;
				}
			}
		}
	}
	
	ss.rgb = mix(ss.rgb, color_inner.rgb, is_inner ? color_inner.a : 0.0);
	ALBEDO = mix(ss.rgb, color_outline.rgb, is_outline ? color_outline.a : 0.0);
}