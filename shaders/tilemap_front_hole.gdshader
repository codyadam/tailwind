shader_type canvas_item;

// Percent of min(viewport width, height). 50% = hole radius to nearest screen edge from center.
uniform float hole_radius_pct : hint_range(0.0, 100.0, 0.1) = 34.0;
// Edge band width, same % basis (smooth or dither).
uniform float fade_softness_pct : hint_range(0.0, 25.0, 0.1) = 10.0;
// Ordered Bayer (8×8) dither vs smooth smoothstep in the edge band.
uniform bool use_dither = false;

// M2: [[0,2],[3,1]] with (x,y) in {0,1}.
int bayer2_idx(int x, int y) {
	x &= 1;
	y &= 1;
	if (x == y) {
		return x == 0 ? 0 : 1;
	}
	return x == 0 ? 3 : 2;
}

// Mn for n=4,8 via M2n(i,j) = 4*Mn(i mod n, j mod n) + M2(floor(i/n), floor(j/n)).
int bayer4_idx(int x, int y) {
	x &= 3;
	y &= 3;
	return 4 * bayer2_idx(x, y) + bayer2_idx(x >> 1, y >> 1);
}

int bayer8_idx(int x, int y) {
	x &= 7;
	y &= 7;
	return 4 * bayer4_idx(x, y) + bayer2_idx(x >> 2, y >> 2);
}

float ordered_bayer8_threshold(vec2 frag_px) {
	ivec2 p = ivec2(mod(floor(frag_px), 8.0));
	int v = bayer8_idx(p.x, p.y);
	return float(v) / 64.0;
}

void fragment() {
	vec2 viewport_px = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 center_px = viewport_px * 0.5;
	float vmin = min(viewport_px.x, viewport_px.y);
	float hole_radius = hole_radius_pct * 0.01 * vmin;
	float fade_softness = fade_softness_pct * 0.01 * vmin;
	float d = distance(FRAGCOORD.xy, center_px);
	float inner = max(hole_radius - fade_softness * 0.5, 0.0);
	float outer = hole_radius + fade_softness * 0.5;
	float vis;
	if (use_dither) {
		if (d <= inner) {
			vis = 0.0;
		} else if (d >= outer) {
			vis = 1.0;
		} else {
			float t = (d - inner) / max(outer - inner, 1e-4);
			float b = ordered_bayer8_threshold(FRAGCOORD.xy);
			vis = step(b, t);
		}
	} else {
		vis = smoothstep(inner, outer, d);
	}
	COLOR.a *= vis;
}
