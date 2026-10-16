shader_type canvas_item;
// Authored soil texture, darkened with depth below the terrain's highest point (stage lighting).
// Darkening is quantised to 4 bands so it reads as pixel-art shading, not a smooth gradient.
// `detail` scales the texture's contrast around its average colour: the terrain body stays a calm
// mass with a soft pattern, so the gameplay surface bands (grass, sand, goo, ice) carry the eye.
uniform float top_y = 0.0;
uniform float depth_px = 700.0;
uniform float dark = 0.55;
uniform vec3 mean_color = vec3(0.5);
uniform float detail = 0.35;
varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = mean_color + (c.rgb - mean_color) * detail;
	float k = clamp((wy - top_y) / depth_px, 0.0, 1.0);
	k = floor(k * 4.0) / 4.0;
	COLOR = vec4(rgb * mix(1.0, 1.0 - dark, k), c.a) * COLOR;
}
