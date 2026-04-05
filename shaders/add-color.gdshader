shader_type canvas_item;

uniform vec4 add_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
    vec4 tex_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    // "Normal" blend: blend add_color over tex_color using add_color.a as opacity
    COLOR = mix(tex_color, add_color, add_color.a);
}