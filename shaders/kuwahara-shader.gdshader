shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

// World-space kernel scale (same role as blur_spread in test.gdshader).
uniform float kernel_spread : hint_range(0.001, 50.0, 0.01) = 2.0;
uniform vec2 canvas_scale = vec2(1.0, 1.0);
uniform int radius : hint_range(1, 5, 1) = 3;
uniform float edge_clamp : hint_range(0.0, 0.02, 0.0001) = 0.001;

varying vec2 world_uv;

const int MAX_R = 5;

void vertex() {
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float wx = length(dFdx(world_uv));
	float wy = length(dFdy(world_uv));
	float world_per_px = max(max(wx, wy), 1e-6);
	vec2 duv = SCREEN_PIXEL_SIZE * kernel_spread * canvas_scale / world_per_px;

	float count[8];
	vec3 sum_rgb[8];
	float sum_lum[8];
	float sum_lum_sq[8];
	for (int i = 0; i < 8; i++) {
		count[i] = 0.0;
		sum_rgb[i] = vec3(0.0);
		sum_lum[i] = 0.0;
		sum_lum_sq[i] = 0.0;
	}

	int r2 = radius * radius;

	for (int dy = -MAX_R; dy <= MAX_R; dy++) {
		for (int dx = -MAX_R; dx <= MAX_R; dx++) {
			int d2 = dx * dx + dy * dy;
			if (d2 > r2) {
				continue;
			}

			int sector;
			if (dx == 0 && dy == 0) {
				sector = 0;
			} else {
				float t = atan(float(dy), float(dx)) + PI;
				sector = int(floor(t * (4.0 / PI)));
				sector = clamp(sector, 0, 7);
			}

			vec2 suv = SCREEN_UV + vec2(float(dx), float(dy)) * duv;
			suv = clamp(suv, vec2(edge_clamp), vec2(1.0 - edge_clamp));
			vec4 c = texture(SCREEN_TEXTURE, suv);
			vec3 rgb = c.rgb;
			float lum = dot(rgb, vec3(0.299, 0.587, 0.114));

			sum_rgb[sector] += rgb;
			sum_lum[sector] += lum;
			sum_lum_sq[sector] += lum * lum;
			count[sector] += 1.0;
		}
	}

	float best_var = 1e20;
	vec3 best_rgb = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	for (int s = 0; s < 8; s++) {
		if (count[s] < 1.0) {
			continue;
		}
		float m = sum_lum[s] / count[s];
		float v = sum_lum_sq[s] / count[s] - m * m;
		if (v < best_var) {
			best_var = v;
			best_rgb = sum_rgb[s] / count[s];
		}
	}

	float a = texture(SCREEN_TEXTURE, SCREEN_UV).a;
	COLOR = vec4(best_rgb, a);
}
