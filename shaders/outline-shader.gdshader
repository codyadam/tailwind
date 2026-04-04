shader_type canvas_item;


/// Thickness in viewport pixels (stable under scale & non-square sprites).
uniform float width_px : hint_range(0.0, 64.0, 0.5) = 2.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool no_texture = false;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Distance from each UV edge in screen pixels (|∇UV| is UV delta per ~1 px step).
	const float EPS = 1e-5;
	float gu = max(length(vec2(dFdx(UV.x), dFdy(UV.x))), EPS);
	float gv = max(length(vec2(dFdx(UV.y), dFdy(UV.y))), EPS);
	float dist_u_px = min(UV.x, 1.0 - UV.x) / gu;
	float dist_v_px = min(UV.y, 1.0 - UV.y) / gv;
	bool outside = dist_u_px < width_px || dist_v_px < width_px;

	
	if (outside) {
		if (!no_texture) {
			COLOR = color + texture(TEXTURE, UV);
		} else {
			COLOR = color;
		}
	} else {
		if (!no_texture) {
			COLOR = texture(TEXTURE, UV);
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		}
	}
}