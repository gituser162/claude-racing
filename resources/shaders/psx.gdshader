shader_type spatial;
// Базовий матеріал у стилі PS1:
//  - вершини прилипають до екранної сітки («тремтіння»);
//  - афінні текстури без перспективної корекції;
//  - освітлення по вершинах, без бліків;
//  - текстури без фільтрації.
render_mode vertex_lighting, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Розмір «сітки», до якої прилипають вершини (менше — сильніше тремтить). 0 — вимкнено.
uniform vec2 snap_grid = vec2(320.0, 180.0);
// 1.0 — повністю афінні текстури, 0.0 — звичайні.
uniform float affine_strength = 1.0;

varying vec2 persp_uv;
varying vec3 affine_uv;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_grid.x > 0.0 && clip.w > 0.0) {
		vec2 half_grid = snap_grid * 0.5;
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * half_grid + 0.5) / half_grid;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	vec2 uv = UV * uv_scale;
	persp_uv = uv;
	affine_uv = vec3(uv * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(persp_uv, affine_uv.xy / affine_uv.z, affine_strength);
	ALBEDO = albedo.rgb * texture(albedo_texture, uv).rgb;
	EMISSION = emission.rgb * emission_energy;
	ROUGHNESS = 1.0;
}
