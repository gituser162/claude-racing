shader_type spatial;
// Напівпрозоре «енергетичне» світіння (щит, сліди вогнів, дощ): додається до картинки.
// rim = true — світліше по краях (для куль-щитів). Колір вершин множиться на color.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.3, 1.0, 0.7, 1.0);
uniform float intensity = 0.8;
uniform bool rim = true;
uniform vec2 snap_grid = vec2(320.0, 180.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_grid.x > 0.0 && clip.w > 0.0) {
		vec2 half_grid = snap_grid * 0.5;
		clip.xy = floor(clip.xy / clip.w * half_grid + 0.5) / half_grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float shape = 1.0;
	if (rim) {
		float r = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		shape = 0.25 + r * r * 1.5;
	}
	ALBEDO = color.rgb * intensity * shape * COLOR.rgb;
}
