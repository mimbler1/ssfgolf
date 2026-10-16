shader_type canvas_item;
// Paper sky for the ink worlds (docs/INK_ART_SPEC.md §9): a soft vertical gradient, fixed paper
// grain, and very faint large swirl motifs. Screen space; costs one full-screen quad.

uniform vec4 top_color : source_color = vec4(0.75, 0.86, 0.93, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.96, 0.94, 0.89, 1.0);
uniform vec4 swirl_color : source_color = vec4(0.91, 0.88, 0.82, 1.0);
uniform float grain = 0.05;
uniform float aspect = 1.777;
uniform float horizon_shift = 0.0;
uniform vec2 scroll = vec2(0.0);

// Hash without sine (Dave Hoskins): stable for the pixel-sized inputs used here.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

// Distance to an Archimedean spiral arm around `c` (in uv units).
float spiral(vec2 uv, vec2 c, float s) {
	vec2 d = (uv - c) / s;
	float r = length(d);
	float a = atan(d.y, d.x);
	float turns = (r - (a + 3.14159) / 6.28318 * 0.18) / 0.18;
	float k = abs(fract(turns) - 0.5) * 0.18;
	return (r < 0.62 && r > 0.04) ? k * s : 1.0;
}

void fragment() {
	vec2 uv = UV;
	float t = clamp(uv.y + horizon_shift, 0.0, 1.0);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, t));
	// Faint swirls drifting slowly with the camera (deep parallax).
	vec2 suv = vec2(uv.x * aspect, uv.y) + scroll * vec2(0.02, 0.01);
	vec2 cell = floor(suv / 0.9);
	vec2 loc = fract(suv / 0.9);
	float h = hash(cell);
	if (h > 0.55) {
		vec2 c = vec2(0.3 + 0.4 * hash(cell + 3.1), 0.3 + 0.4 * hash(cell + 7.7));
		float d = spiral(loc, c, 0.55 + 0.3 * h);
		float line = 1.0 - smoothstep(0.004, 0.012, d);
		col = mix(col, swirl_color.rgb, line * 0.35 * (1.0 - t * 0.6));
	}
	// Paper grain: fine fibres plus a soft mottling.
	vec2 px = FRAGCOORD.xy;
	float fine = hash(floor(px * 0.75)) - 0.5;
	float mottle = vnoise(px * 0.012) - 0.5;
	col += (fine * 0.6 + mottle * 1.4) * grain;
	// Gentle vignette.
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.18;
	COLOR = vec4(col, 1.0);
}
