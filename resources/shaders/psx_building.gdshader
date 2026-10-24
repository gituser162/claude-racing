shader_type spatial;
// Хмарочос: темні стіни з сіткою вікон у світових координатах.
// Частина вікон світиться (вибір — псевдовипадковий за номером вікна).
render_mode vertex_lighting, specular_disabled;

uniform vec4 wall_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform vec2 window_cell = vec2(3.0, 3.6);
uniform float lit_ratio = 0.35;
uniform float window_energy = 1.6;
uniform vec4 warm : source_color = vec4(1.0, 0.75, 0.45, 1.0);
uniform vec4 cool : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.35, 0.8, 1.0);
uniform vec2 snap_grid = vec2(320.0, 180.0);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (snap_grid.x > 0.0 && clip.w > 0.0) {
		vec2 half_grid = snap_grid * 0.5;
		clip.xy = floor(clip.xy / clip.w * half_grid + 0.5) / half_grid * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	ALBEDO = wall_color.rgb;
	ROUGHNESS = 1.0;
	vec3 n = abs(world_normal);
	if (n.y < 0.5 && world_pos.y > 1.5) {
		// Координата вздовж стіни: по X або по Z залежно від напрямку грані.
		float along = n.x > n.z ? world_pos.z : world_pos.x;
		vec2 p = vec2(along, world_pos.y) / window_cell;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float in_window = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
		float seed = hash(cell + floor(world_pos.xz * 0.02) * 17.0 + (n.x > n.z ? 0.0 : 91.0));
		float lit = step(1.0 - lit_ratio, seed);
		vec3 tint = seed > 0.93 ? pink.rgb : (seed > 0.8 ? cool.rgb : warm.rgb);
		ALBEDO = mix(wall_color.rgb, vec3(0.02), in_window);
		EMISSION = tint * in_window * lit * window_energy * (0.6 + 0.4 * hash(cell * 3.1));
	}
}
