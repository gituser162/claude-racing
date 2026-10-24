shader_type canvas_item;
// Пост-ефект на весь екран: обмежена палітра (~15 біт) з дизерингом, як на PS1,
// і легкі «скан-лінії» ЕПТ-екрана.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float color_levels = 32.0;
uniform float dither_strength = 1.0;
uniform float scanline_strength = 0.07;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = (BAYER[p.y * 4 + p.x] / 16.0 - 0.5) * dither_strength;
	color = floor(color * (color_levels - 1.0) + 0.5 + threshold) / (color_levels - 1.0);
	color *= 1.0 - scanline_strength * mod(floor(FRAGCOORD.y), 2.0);
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
