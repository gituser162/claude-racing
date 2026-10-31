shader_type spatial;
// Напівпрозоре «енергетичне» світіння (щит, сліди вогнів, дощ, спалахи): додається до картинки.
// rim = true — світліше по краях (для куль-щитів). Колір вершин множиться на color.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 color : source_color = vec4(0.3, 1.0, 0.7, 1.0);
uniform float intensity = 0.8;
uniform bool rim = true;
// Реакція на біт музики (global beat_pulse, ставить Audio): 0 — ні, 1 — спалахує в такт.
global uniform float beat_pulse;
uniform float beat_react = 0.0;
// Застарілий параметр (тремтіння вершин) — більше не діє.
uniform vec2 snap_grid = vec2(0.0);

void fragment() {
	float shape = 1.0;
	if (rim) {
		float r = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		shape = 0.25 + r * r * 1.5;
	}
	ALBEDO = color.rgb * intensity * shape * COLOR.rgb * (1.0 + beat_react * beat_pulse * 1.2);
}
