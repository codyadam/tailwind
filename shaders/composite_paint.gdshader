shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D scene_tex : filter_linear, repeat_disable;
uniform sampler2D paint_tex : filter_linear, repeat_disable;
uniform float paint_strength : hint_range(0.0, 1.0, 0.01) = 0.75;

void fragment() {
	vec2 uv = UV;
	vec3 scene = texture(scene_tex, uv).rgb;
	vec4 paint = texture(paint_tex, uv);
	float w = clamp(paint.a * paint_strength, 0.0, 1.0);
	COLOR.rgb = mix(scene, paint.rgb, w);
	COLOR.a = 1.0;
}
