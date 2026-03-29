shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D scene_tex : filter_linear, repeat_disable;
uniform sampler2D prev_accum : filter_linear, repeat_disable;
uniform sampler2D brush_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

uniform vec2 paint_viewport_size = vec2(576.0, 324.0);
uniform vec2 world_viewport_size = vec2(1152.0, 648.0);

group_uniforms tiles;
uniform float tile_px : hint_range(4.0, 128.0, 1.0) = 24.0;
uniform float spawn_threshold : hint_range(0.0, 1.0, 0.001) = 0.22;
uniform float frame_seed = 0.0;
group_uniforms;

group_uniforms stroke;
uniform float decay : hint_range(0.85, 1.0, 0.001) = 0.992;
uniform float stroke_opacity : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float angle_spread : hint_range(0.0, 3.14159, 0.01) = 1.2;
uniform float scale_min : hint_range(0.2, 2.5, 0.01) = 0.55;
uniform float scale_max : hint_range(0.2, 2.5, 0.01) = 1.05;
uniform float noise_scale_uv : hint_range(0.1, 8.0, 0.1) = 2.4;
group_uniforms;

group_uniforms direction;
uniform float use_gradient_dir : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float gradient_sobel_radius_px : hint_range(0.5, 3.0, 0.5) = 1.0;
group_uniforms;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + frame_seed * 0.001) * 43758.5453123);
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec2 scene_grad_at(vec2 scene_uv) {
	float r = max(gradient_sobel_radius_px, 0.5);
	vec2 px = r / world_viewport_size;
	vec3 s_left = texture(scene_tex, scene_uv + vec2(-px.x, 0.0)).rgb;
	vec3 s_right = texture(scene_tex, scene_uv + vec2(px.x, 0.0)).rgb;
	vec3 s_down = texture(scene_tex, scene_uv + vec2(0.0, -px.y)).rgb;
	vec3 s_up = texture(scene_tex, scene_uv + vec2(0.0, px.y)).rgb;
	float gx = luminance(s_right) - luminance(s_left);
	float gy = luminance(s_up) - luminance(s_down);
	return vec2(gx, gy);
}

void fragment() {
	vec2 uv = UV;
	vec4 prev = texture(prev_accum, uv);
	prev.rgb *= decay;
	prev.a = clamp(prev.a * decay, 0.0, 1.0);

	vec2 scen_uv = uv;
	vec4 scen_sample = texture(scene_tex, scen_uv);
	vec3 base_scene = scen_sample.rgb;

	vec2 psize = max(paint_viewport_size, vec2(1.0));
	float tiles_x = max(floor(psize.x / max(tile_px, 1.0)), 1.0);
	float tiles_y = max(floor(psize.y / max(tile_px, 1.0)), 1.0);
	vec2 tile_count = vec2(tiles_x, tiles_y);

	vec2 tile_id = floor(uv * tile_count);
	vec2 tile_f = fract(uv * tile_count);

	vec2 noise_uv = (tile_id + 0.5) / tile_count * noise_scale_uv + vec2(frame_seed * 0.017, frame_seed * 0.023);
	float nThumb = texture(noise_tex, noise_uv).r;

	if (nThumb >= spawn_threshold) {
		COLOR = prev;
	} else {
		vec2 hid = tile_id + vec2(frame_seed * 0.31, frame_seed * 0.27);
		float h0 = hash21(hid);
		float h1 = hash21(hid + vec2(19.1, 2.7));
		float h2 = hash21(hid + vec2(5.3, 11.9));
		float h3 = hash21(hid + vec2(8.8, 3.1));

		vec2 jitter = (vec2(h2, h3) - 0.5) * 0.65 / tile_count;
		vec2 center_uv = (tile_id + vec2(0.5)) / tile_count + jitter;
		vec2 center_scene_uv = center_uv;

		vec3 picked = texture(scene_tex, center_scene_uv).rgb;

		vec2 g = scene_grad_at(center_scene_uv);
		float angle = (h0 - 0.5) * 2.0 * angle_spread;
		if (use_gradient_dir > 0.5 && length(g) > 1e-4) {
			float ga = atan(g.y, g.x) + 1.57079632679;
			angle = mix(angle, ga, 0.65);
		}

		float sc = mix(scale_min, scale_max, h1);
		vec2 local = (uv - center_uv) * tile_count * 2.0;

		float co = cos(angle);
		float si = sin(angle);
		vec2 rot = vec2(co * local.x - si * local.y, si * local.x + co * local.y);
		rot /= max(sc, 0.08);

		vec2 brush_uv = rot + vec2(0.5);
		float edge = smoothstep(0.0, 0.04, brush_uv.x) * smoothstep(1.0, 0.96, brush_uv.x);
		edge *= smoothstep(0.0, 0.04, brush_uv.y) * smoothstep(1.0, 0.96, brush_uv.y);

		vec4 bsample = texture(brush_tex, clamp(brush_uv, vec2(0.001), vec2(0.999)));
		float mask = (1.0 - bsample.r) * edge;
		float a = clamp(mask * stroke_opacity, 0.0, 1.0);

		vec3 out_rgb = mix(prev.rgb, picked, a);
		float out_a = clamp(prev.a + (1.0 - prev.a) * a, 0.0, 1.0);

		COLOR = vec4(out_rgb, out_a);
	}
}
