shader_type canvas_item;
// Пост-ефект на весь екран у стилі HD-PS1: м'яке кольорокорегування нічного міста.
//  - тіні трохи підняті в холодний фіолетовий (як смог, що підсвічує місто);
//  - легка насиченість і віньєтка, щоб погляд тримався в центрі;
//  - ледь помітне зерно великими «пікселями».

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec3 shadow_tint : source_color = vec3(0.025, 0.012, 0.05);
uniform float saturation = 1.12;
uniform float vignette = 0.38;
uniform float grain = 0.025;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, saturation);
	color += shadow_tint * (1.0 - smoothstep(0.0, 0.5, luma));
	vec2 v = SCREEN_UV - 0.5;
	color *= 1.0 - vignette * dot(v, v) * 2.0;
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	color += (fract(sin(dot(cell + floor(TIME * 24.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * grain;
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
