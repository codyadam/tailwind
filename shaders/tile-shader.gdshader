shader_type canvas_item;

// Max displacement in canvas/world units (same space as MODEL_MATRIX * VERTEX).
uniform float jitter_strength : hint_range(0.0, 32.0, 0.1) = 2.0;
// Snap world XY to this grid before hashing so neighbors agree on shared corners (0 = off, try 0.01–1 if you see hairline cracks).
uniform float corner_snap : hint_range(0.0, 8.0, 0.001) = 0.0;
uniform float jitter_seed = 0.0;

float hash11(vec2 p) {
	return fract(sin(dot(p + jitter_seed, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash22(vec2 p) {
	return vec2(hash11(p), hash11(p + vec2(19.19, 47.47)));
}

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 key = corner_snap > 1e-6 ? floor(world / corner_snap + 1e-4) * corner_snap : world;
	vec2 n = hash22(key) * 2.0 - 1.0;
	vec2 world_jittered = world + n * jitter_strength;
	vec4 local4 = inverse(MODEL_MATRIX) * vec4(world_jittered, 0.0, 1.0);
	VERTEX = local4.xy;
}

void fragment() {
	// Called for every pixel the material is visible on.
}

