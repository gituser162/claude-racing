shader_type spatial;
// Хмарочос у стилі HD-PS1: стіни з великих «текселів» (бетонні панелі, шви між поверхами)
// і сітка вікон у світових координатах. Частина вікон світиться, усередині вікна —
// піксельні жалюзі й силуети, тож вогні міста не виглядають рівними прямокутниками.

uniform vec4 wall_color : source_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform vec2 window_cell = vec2(3.0, 3.6);
uniform float lit_ratio = 0.35;
uniform float window_energy = 1.6;
uniform vec4 warm : source_color = vec4(1.0, 0.75, 0.45, 1.0);
uniform vec4 cool : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform vec4 pink : source_color = vec4(1.0, 0.35, 0.8, 1.0);
// Скільки текселів фасаду на метр.
uniform float texel_density = 4.0;
// Застарілий параметр (тремтіння вершин) — більше не діє.
uniform vec2 snap_grid = vec2(0.0);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	vec3 n = abs(world_normal);
	float side = n.x > n.z ? 0.0 : 91.0;
	float along = n.x > n.z ? world_pos.z : world_pos.x;
	vec2 face = n.y < 0.5 ? vec2(along, world_pos.y) : world_pos.xz;
	// Тексел стіни: невеликі перепади яскравості плюс плями бруду на кілька текселів.
	vec2 texel = floor(face * texel_density);
	float noise = 0.82 + 0.3 * hash(texel + side) + 0.18 * (hash(floor(texel / 4.0) + 7.0) - 0.5);
	vec3 wall = wall_color.rgb * noise;
	if (n.y >= 0.5 || world_pos.y <= 1.5) {
		ALBEDO = wall;
	} else {
		vec2 p = vec2(along, world_pos.y) / window_cell;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		// Шов між поверхами (темний) і світліший карниз над ним.
		float seam = step(f.y, 0.05);
		float ledge = step(0.05, f.y) * step(f.y, 0.1);
		wall *= 1.0 - 0.45 * seam + 0.35 * ledge;
		float in_window = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
		float frame = step(0.15, f.x) * step(f.x, 0.85) * step(0.2, f.y) * step(f.y, 0.8) - in_window;
		float seed = hash(cell + floor(world_pos.xz * 0.02) * 17.0 + side);
		float lit = step(1.0 - lit_ratio, seed);
		vec3 tint = seed > 0.93 ? pink.rgb : (seed > 0.8 ? cool.rgb : warm.rgb);
		// Всередині вікна: піксельні жалюзі (смуги) або силует-штора збоку.
		vec2 wp = floor(f * vec2(10.0, 12.0));
		float blinds = hash(cell * 1.7) > 0.5 ? 0.7 + 0.3 * mod(wp.y, 2.0) : 1.0;
		float curtain = step(hash(cell * 2.3) * 0.5 + 0.35, f.x) * step(0.6, hash(cell * 4.1));
		float glow = (0.55 + 0.45 * hash(cell * 3.1)) * blinds * (1.0 - 0.75 * curtain);
		glow *= 0.85 + 0.3 * hash(wp + cell);
		ALBEDO = mix(wall * (1.0 + 0.8 * frame), vec3(0.02, 0.025, 0.035), in_window);
		EMISSION = tint * in_window * lit * window_energy * glow;
	}
}
