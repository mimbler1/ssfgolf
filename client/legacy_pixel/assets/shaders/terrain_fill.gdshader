shader_type canvas_item;
// Soil fill: depth gradient, wavy strata bands and pebble speckles in world space.

uniform vec4 top_color : source_color = vec4(0.54, 0.35, 0.24, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.36, 0.23, 0.16, 1.0);
uniform vec4 strata_color : source_color = vec4(0.48, 0.31, 0.2, 1.0);
uniform float top_y = -200.0;
uniform float depth = 900.0;

varying vec2 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = clamp((world_pos.y - top_y) / depth, 0.0, 1.0);
	vec3 c = mix(top_color.rgb, bottom_color.rgb, t);
	float band = sin(world_pos.y * 0.035 + sin(world_pos.x * 0.004) * 2.5 + vnoise(world_pos * 0.01) * 1.5);
	c = mix(c, strata_color.rgb, smoothstep(0.72, 0.9, band) * 0.55);
	float pebble = smoothstep(0.78, 0.82, vnoise(world_pos * 0.09));
	c = mix(c, c * 0.78, pebble * 0.6);
	float light = smoothstep(0.8, 0.84, vnoise(world_pos * 0.07 + 13.0));
	c = mix(c, c * 1.15, light * 0.4);
	COLOR = vec4(c, 1.0);
}
