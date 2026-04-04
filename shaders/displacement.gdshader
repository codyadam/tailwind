shader_type canvas_item;

/// Screen buffer to warp. Use on a fullscreen ColorRect / post layer after a `BackBufferCopy`.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms flow_map;
/// RG encode direction: (0.5, 0.5) = no flow. Remapped to [-1, 1] per axis (tangent-style flow map).
uniform vec2 rg_mul = vec2(2.0, 2.0);
uniform vec2 rg_add = vec2(-1.0, -1.0);
/// Flip or scale axes (e.g. `(1, -1)` if your map’s green channel is inverted vs screen Y).
uniform vec2 flow_swizzle = vec2(1.0, 1.0);
/// When > 0, flow length is multiplied by `mix(1.0, B * blue_scale, blue_mix)` for packed “speed in blue” maps.
uniform float blue_mix : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float blue_scale : hint_range(0.0, 4.0, 0.01) = 2.0;
/// Peak UV offset in **pixels** (before optional multi-tap spread).
uniform float displacement_px : hint_range(0.0, 256.0, 1.0) = 32.0;
/// 1 = single refractive sample at full offset. >1 = blend samples from undistorted → full offset (advection smear).
uniform int advect_steps : hint_range(1, 12, 1) = 1;
/// Bias weights toward the leading edge (higher = sharper “head”, more trail smear).
uniform float trail_sharpness : hint_range(0.1, 8.0, 0.05) = 2.0;

group_uniforms uv;
uniform float edge_clamp : hint_range(0.0, 0.05, 0.0005) = 0.002;

group_uniforms debug;
/// When 1, draws only `TEXTURE` at `UV` (no flow, no `SCREEN_TEXTURE`).
uniform bool debug_show_texture = false;

const int MAX_ADVECT = 12;

void fragment() {
	if (debug_show_texture) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 clamp_lo = vec2(edge_clamp);
		vec2 clamp_hi = vec2(1.0 - edge_clamp);

		vec4 f = texture(TEXTURE, UV);
		vec2 flow = (f.rg * rg_mul + rg_add) * flow_swizzle;
		if (blue_mix > 0.001) {
			float bm = mix(1.0, f.b * blue_scale, clamp(blue_mix, 0.0, 1.0));
			flow *= bm;
		}

		vec2 duv = flow * displacement_px * SCREEN_PIXEL_SIZE;

		int n = clamp(advect_steps, 1, MAX_ADVECT);
		vec3 acc = vec3(0.0);
		float wsum = 0.0;

		if (n == 1) {
			vec2 suv = clamp(SCREEN_UV + duv, clamp_lo, clamp_hi);
			acc = texture(SCREEN_TEXTURE, suv).rgb;
			wsum = 1.0;
		} else {
			for (int i = 0; i < MAX_ADVECT; i++) {
				if (i >= n) {
					break;
				}
				float t = float(i) / float(n - 1);
				vec2 suv = clamp(SCREEN_UV + duv * t, clamp_lo, clamp_hi);
				float w = pow(1.0 - t + 0.001, trail_sharpness);
				acc += texture(SCREEN_TEXTURE, suv).rgb * w;
				wsum += w;
			}
		}

		vec2 base_uv = clamp(SCREEN_UV, clamp_lo, clamp_hi);
		float a = texture(SCREEN_TEXTURE, base_uv).a;
		COLOR = vec4(acc / max(wsum, 1e-5), a);
	}
}
