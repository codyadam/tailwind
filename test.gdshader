shader_type canvas_item;

#include "res://addons/shaderV/rgba/noise/simplex2d.gdshaderinc"

// Screen buffer from before this item is drawn (blur what is “behind”).
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

// Gaussian σ in tap-grid units (controls how soft the falloff is inside the kernel).
uniform float blur_sigma : hint_range(0.4, 8.0, 0.05) = 2.0;

// World-space blur radius (same units as canvas world_uv). Wider when zoomed in / smaller world_per_px.
uniform float blur_spread : hint_range(0.001, 50.0, 0.01) = 1.0;

// Simplex noise domain for the distortion field (shaderV: _simplex2dNoiseFunc).
uniform float noise_scale : hint_range(0.01, 0.5, 0.001) = 0.25;
uniform vec2 noise_offset = vec2(0.0, 0.0);
// UV displacement strength from noise (scaled with blur so it stays stable in world units).
uniform float distort_strength : hint_range(0.0, 0.08, 0.0001) = 0.012;
// Optional extra scale from script (e.g. get_viewport().get_canvas_transform().get_scale()) if you still see drift.
uniform vec2 canvas_scale = vec2(1.0, 1.0);
// Animate the noise field (multiplies built-in TIME on X/Y).
uniform float noise_time_scale : hint_range(0.0, 4.0, 0.05) = 0.0;

// Interpolated canvas/world XY so the noise field stays fixed in the scene when the camera moves.
varying vec2 world_uv;

void vertex() {
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// World units per screen pixel (canvas space). Tracks Camera2D zoom, stretch, and viewport scale without a uniform.
	float wx = length(dFdx(world_uv));
	float wy = length(dFdy(world_uv));
	float world_per_px = max(max(wx, wy), 1e-6);
	// Screen-space kernel size that keeps ~constant world thickness; canvas_scale fixes rare cases derivatives miss.
	vec2 step_uv = SCREEN_PIXEL_SIZE * blur_spread * canvas_scale / world_per_px;
	float denom = max(blur_sigma * blur_sigma * 2.0, 1e-4);

	// Two independent-ish simplex channels → 2D distortion (shaderV noise as displacement texture).
	// Use world_uv (not SCREEN_UV) so the pattern is anchored to world space, not the viewport.
	vec2 ncoord = world_uv * noise_scale + noise_offset + vec2(TIME * noise_time_scale);
	float n0 = _simplex2dNoiseFunc(ncoord);
	float n1 = _simplex2dNoiseFunc(ncoord + vec2(17.234, 9.123));
	vec2 disp = (vec2(n0, n1) - 0.5) * 2.0;
	vec2 blur_center = SCREEN_UV + disp * distort_strength * canvas_scale / world_per_px;

	vec4 acc = vec4(0.0);
	float wsum = 0.0;

	// Gaussian blur of SCREEN_TEXTURE, centered on the warped UV (blur evaluated through distortion).
	for (int y = -6; y <= 6; y++) {
		for (int x = -6; x <= 6; x++) {
			float d = float(x * x + y * y);
			float w = exp(-d / denom);
			vec2 suv = blur_center + vec2(float(x), float(y)) * step_uv;
			acc += texture(SCREEN_TEXTURE, suv) * w;
			wsum += w;
		}
	}

	COLOR = acc / wsum;
}
