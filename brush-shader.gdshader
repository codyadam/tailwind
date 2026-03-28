shader_type canvas_item;
render_mode blend_mix;

#include "res://addons/shaderV/rgba/noise/simplex2d.gdshaderinc"

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D brush_tex : source_color, filter_linear, repeat_disable;

group_uniforms grid;
uniform float stroke_density : hint_range(4.0, 160.0, 1.0) = 36.0;
uniform float seed = 0.0;
group_uniforms;

group_uniforms stroke;
uniform float angle_spread : hint_range(0.0, 3.14159, 0.01) = 0.85;
uniform float scale_min : hint_range(0.15, 2.5, 0.01) = 0.55;
uniform float scale_max : hint_range(0.15, 2.5, 0.01) = 1.05;
uniform float cell_center_jitter : hint_range(0.0, 0.45, 0.01) = 0.12;
group_uniforms;

group_uniforms noise;
uniform float noise_scale : hint_range(0.02, 2.0, 0.01) = 0.35;
uniform vec2 noise_offset = vec2(0.0, 0.0);
uniform float noise_jitter : hint_range(0.0, 0.35, 0.005) = 0.06;
uniform float noise_time_scale : hint_range(0.0, 2.0, 0.05) = 0.0;
group_uniforms;

group_uniforms look;
uniform float stroke_opacity : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float color_variation : hint_range(0.0, 0.45, 0.01) = 0.12;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);
group_uniforms;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453123);
}

void fragment() {
	vec4 base = texture(SCREEN_TEXTURE, SCREEN_UV);

	float dens = max(stroke_density, 1.0);
	vec2 cell = floor(SCREEN_UV * dens);
	vec2 cell_f = fract(SCREEN_UV * dens);

	vec2 cell_norm = cell / dens;
	float t = TIME * noise_time_scale;
	float n0 = _simplex2dNoiseFunc(cell_norm * noise_scale + noise_offset + vec2(t * 0.07, 0.0));
	float n1 = _simplex2dNoiseFunc(cell_norm * noise_scale + noise_offset + vec2(19.2, 8.4) + vec2(0.0, t * 0.07));
	vec2 sj = (vec2(n0, n1) - 0.5) * 2.0 * noise_jitter;
	vec2 local = cell_f - vec2(0.5) + sj;

	vec2 hid = cell + vec2(seed * 31.4159, seed * 27.1828);
	float h0 = hash21(hid);
	float h1 = hash21(hid + vec2(13.7, 2.9));
	float h2 = hash21(hid + vec2(7.1, 19.3));
	float h3 = hash21(hid + vec2(3.3, 41.1));

	float angle = (h0 - 0.5) * 2.0 * angle_spread;
	float sc = mix(scale_min, scale_max, h1);
	vec2 center_off = (vec2(h2, h3) - 0.5) * 2.0 * cell_center_jitter;
	local -= center_off;

	float co = cos(angle);
	float si = sin(angle);
	vec2 rot = vec2(co * local.x - si * local.y, si * local.x + co * local.y);
	rot /= max(sc, 0.05);

	vec2 brush_uv = rot + vec2(0.5);

	float edge = smoothstep(0.0, 0.03, brush_uv.x) * smoothstep(1.0, 0.97, brush_uv.x);
	edge *= smoothstep(0.0, 0.03, brush_uv.y) * smoothstep(1.0, 0.97, brush_uv.y);

	vec4 bsample = texture(brush_tex, clamp(brush_uv, vec2(0.001), vec2(0.999)));
	float m = (1.0 - bsample.r) * edge;

	vec2 pick_uv = (cell + vec2(0.5)) / dens;
	vec3 picked = texture(SCREEN_TEXTURE, pick_uv).rgb;
	vec3 var_rgb = picked * mix(vec3(1.0 - color_variation), vec3(1.0 + color_variation), vec3(h2, h3, h1));
	var_rgb *= tint;

	COLOR.rgb = mix(base.rgb, var_rgb, clamp(m * stroke_opacity, 0.0, 1.0));
	COLOR.a = 1.0;
}
