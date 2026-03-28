shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

uniform float canvas_scale : hint_range(0.0, 0.001, 0.000001) = 0.0005;
// Cells per world unit (higher = finer cells).
uniform float density : hint_range(0.002, 2.0, 0.001) = 0.08;
// 1 = random feature in cell; 0 = cell center.
uniform float cell_jitter : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float edge_clamp : hint_range(0.0, 0.02, 0.0001) = 0.001;

varying vec2 world_uv;

vec2 hash2(vec2 p) {
	vec2 q = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453123);
}

void vertex() {
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float wx = length(dFdx(world_uv));
	float wy = length(dFdy(world_uv));
	float world_per_px = max(max(wx, wy), 1e-6);

	vec2 p = world_uv * density;
	vec2 n = floor(p);
	vec2 f = fract(p);
	float min_d = 1e20;
	vec2 delta_grid = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			o = mix(vec2(0.5), o, cell_jitter);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < min_d) {
				min_d = d;
				delta_grid = r;
			}
		}
	}

	vec2 wdelta = delta_grid / max(density, 1e-6);
	vec2 suv = SCREEN_UV + canvas_scale * wdelta / world_per_px;
	suv = clamp(suv, vec2(edge_clamp), vec2(1.0 - edge_clamp));
	vec4 col = texture(SCREEN_TEXTURE, suv);
	COLOR = vec4(col.rgb, texture(SCREEN_TEXTURE, SCREEN_UV).a);
}
