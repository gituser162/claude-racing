shader_type spatial;
// Голограма: напівпрозорий світний силует. Яскраві краї (rim), горизонтальні
// скан-лінії, що повзуть угору, і легке мерехтіння. Додається до картинки (blend_add).
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled;

uniform vec4 color : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform float intensity = 0.8;
// Голограма «дихає» в такт музиці (global beat_pulse, ставить Audio).
global uniform float beat_pulse;
// Кількість скан-ліній на метр і швидкість їх руху вгору.
uniform float line_density = 2.5;
uniform float line_speed = 1.2;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.0);
	float lines = step(0.5, fract(world_pos.y * line_density - TIME * line_speed));
	float flicker = 0.85 + 0.15 * sin(TIME * 23.0) * sin(TIME * 7.0);
	float shape = 0.12 + 1.2 * rim;
	ALBEDO = color.rgb * intensity * shape * (0.45 + 0.55 * lines) * flicker * (1.0 + beat_pulse * 0.7);
}
