shader_type canvas_item;
// Screen-space sky: vertical gradient, soft sun glow with slow rotating rays, gentle vignette.

uniform vec4 top_color : source_color = vec4(0.25, 0.66, 0.96, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.79, 0.94, 1.0, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.77, 1.0);
uniform vec2 sun_uv = vec2(0.78, 0.2);
uniform float sun_size = 0.06;
uniform float rays = 1.0;
uniform float aspect = 1.7778;
uniform float horizon_shift = 0.0;

void fragment() {
	vec2 uv = UV;
	float t = clamp(uv.y + horizon_shift, 0.0, 1.0);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, t));
	vec2 d = (uv - sun_uv) * vec2(aspect, 1.0);
	float r = length(d);
	float glow = exp(-r * 5.5) * 0.55 + exp(-r * 18.0) * 0.5;
	float ang = atan(d.y, d.x);
	float ray = (0.5 + 0.5 * sin(ang * 12.0 + TIME * 0.12)) * exp(-r * 3.2) * 0.12 * rays;
	col = mix(col, sun_color.rgb, clamp(glow + ray, 0.0, 1.0));
	float disc = smoothstep(sun_size, sun_size - 0.006, r);
	col = mix(col, vec3(1.0, 0.99, 0.93), disc);
	float vig = smoothstep(1.25, 0.45, length((uv - vec2(0.5, 0.45)) * vec2(1.0, 1.15)));
	col *= mix(0.9, 1.0, vig);
	COLOR = vec4(col, 1.0);
}
