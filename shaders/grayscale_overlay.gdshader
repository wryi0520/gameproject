shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec2 centered = SCREEN_UV - vec2(0.5);
	float vignette = 1.0 - dot(centered, centered) * vignette_strength * 2.5;
	COLOR = vec4(vec3(gray * clamp(vignette, 0.0, 1.0)), 1.0);
}
