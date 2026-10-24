shader_type spatial;
// Червоно-білі «зебри» бордюру у світових координатах.

uniform vec4 color_a : source_color = vec4(0.85, 0.12, 0.1, 1.0);
uniform vec4 color_b : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float cell_size = 1.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_pos.xz / cell_size);
	ALBEDO = mix(color_a.rgb, color_b.rgb, mod(cell.x + cell.y, 2.0));
	ROUGHNESS = 0.8;
}
