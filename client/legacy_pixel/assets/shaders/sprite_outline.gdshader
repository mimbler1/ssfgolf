shader_type canvas_item;
render_mode blend_disabled;
// Sprite baker composite: downsamples the 2x supersampled character render (the sprite is drawn
// at 0.5 scale so each output pixel's UV lands on a 2x2 texel corner, giving a box filter) and
// puts a thick ink silhouette outline behind it. Output is straight alpha for PNG export.

uniform float width_px = 12.0;          // outline radius in source (supersampled) texels
uniform vec4 line_color : source_color = vec4(0.114, 0.102, 0.169, 1.0);

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec4 src = texture(TEXTURE, UV);      // premultiplied (rendered onto transparent black)
	float o = 0.0;
	for (int r = 1; r <= 4; r++) {
		float rad = width_px * float(r) / 4.0;
		for (int i = 0; i < 28; i++) {
			float a = 6.2831853 * (float(i) + 0.5 * float(r & 1)) / 28.0;
			o = max(o, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * rad * ps).a);
		}
	}
	float out_a = src.a + o * (1.0 - src.a);
	vec3 premul = src.rgb + line_color.rgb * o * (1.0 - src.a);
	COLOR = vec4(out_a > 0.0001 ? premul / out_a : vec3(0.0), out_a);
}
