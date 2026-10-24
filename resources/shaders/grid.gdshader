shader_type spatial;
// Шахова клітинка у світових координатах — щоб на рівній землі було видно швидкість.

uniform vec4 color_a : source_color = vec4(0.24, 0.42, 0.21, 1.0);
uniform vec4 color_b : source_color = vec4(0.20, 0.36, 0.18, 1.0);
uniform float cell_size = 4.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_pos.xz / cell_size);
	float checker = mod(cell.x + cell.y, 2.0);
	ALBEDO = mix(color_a.rgb, color_b.rgb, checker);
	ROUGHNESS = 0.95;
}
