shader_type spatial;
// Об'ємний промінь світла (фари, ліхтарі): конус, що яскравий біля джерела,
// згасає з відстанню й м'яко зникає по краях. У тумані й дощі виглядає як світло в повітрі.
// Сітка — CylinderMesh: UV.y = 0 біля джерела (верх), 1 на кінці.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float intensity = 0.35;
uniform float falloff = 1.6;
// Відстань від камери, на якій промінь повністю зникає в смозі.
uniform float fade_far = 90.0;
uniform float fade_near = 3.0;

void fragment() {
	float along = pow(1.0 - clamp(UV.y, 0.0, 1.0), falloff);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = smoothstep(0.0, 0.7, facing);
	// Ледь помітні «пиловинки»: квантування яскравості по екранних пікселях-блоках.
	vec2 cell = floor(FRAGCOORD.xy / 3.0);
	float grain = 0.85 + 0.3 * fract(sin(dot(cell, vec2(12.9898, 78.233)) + 0.0) * 43758.5453);
	float dist = length(VERTEX);
	// Зникає вдалині (смог) і зблизька — щоб камера, пролітаючи крізь промінь, не засвічувалась.
	float dist_fade = (1.0 - smoothstep(fade_far * 0.35, fade_far, dist)) * smoothstep(fade_near, fade_near * 3.0, dist);
	ALBEDO = color.rgb * intensity * along * edge * grain * dist_fade;
}
