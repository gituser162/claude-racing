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
// Рівень землі: нижче ground_y + 1,5 м вікон немає (цоколь). Для міст нижче нуля (вежа «Спіраль») — висота їхньої землі.
uniform float ground_y = 0.0;
// Музика (усе ставить Audio):
//  - beat_pulse — спалах під біт: неонові (блакитні й рожеві) вікна спалахують у такт;
//  - music_bands_lo/hi — 8 смуг живого спектра 0..1 (низ → верх): будинки-«еквалайзери»;
//  - beat_wave (xyz — звідки, w — секунд відтоді) і beat_wave_strength — світлова хвиля по вікнах
//    міста, що розходиться від гравця на першій долі такту.
global uniform float beat_pulse;
global uniform vec4 music_bands_lo;
global uniform vec4 music_bands_hi;
global uniform vec4 beat_wave;
global uniform float beat_wave_strength;
// Яка частка будинків — «еквалайзери» (вікна-стовпчики стрибають під музику). 1 — цей будинок завжди.
uniform float music_eq_ratio = 0.28;
// Для будинку, висота якого не в масштабі вузла (вежа-циліндр): низ і висота «еквалайзера», м.
uniform float eq_base_y = 0.0;
uniform float eq_height = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;
// Центр будинку (xyz) і висота (w) — будинки це масштабовані куби, висота = масштаб по Y.
varying vec4 building;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	building = vec4(NODE_POSITION_WORLD, length(MODEL_MATRIX[1].xyz));
}

float band_level(int band) {
	if (band < 4) {
		return band == 0 ? music_bands_lo.x : (band == 1 ? music_bands_lo.y : (band == 2 ? music_bands_lo.z : music_bands_lo.w));
	}
	return band == 4 ? music_bands_hi.x : (band == 5 ? music_bands_hi.y : (band == 6 ? music_bands_hi.z : music_bands_hi.w));
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
	if (n.y >= 0.5 || world_pos.y <= ground_y + 1.5) {
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
		float neon_window = step(0.8, seed);
		vec3 emission = tint * in_window * lit * window_energy * glow * (1.0 + neon_window * (beat_pulse * 2.0 - 0.3));
		// Будинок-«еквалайзер»: кожна колонка вікон — смуга спектра (по колу 8 смуг уздовж фасаду),
		// світиться знизу до висоти, що відповідає гучності смуги; колір — від блакитного внизу до рожевого вгорі.
		float bseed = hash(floor(building.xz * 0.5) + 3.7);
		float music_on = step(0.02, dot(music_bands_lo, vec4(1.0)) + dot(music_bands_hi, vec4(1.0)));
		float eq = step(bseed, music_eq_ratio) * music_on;
		if (eq > 0.5) {
			float h = eq_height > 0.0 ? eq_height : building.w;
			float base = eq_height > 0.0 ? eq_base_y : building.y - building.w * 0.5;
			float row = clamp((world_pos.y - base) / max(h, 1.0), 0.0, 1.0);
			int band = int(mod(cell.x + side + floor(bseed * 97.0), 8.0));
			float level = band_level(band);
			float on = step(row, level * 0.97);
			// Верхнє вікно стовпчика — яскравіше (як «пік» на еквалайзері).
			float peak = on * (1.0 - step(row + window_cell.y / max(h, 1.0), level * 0.97));
			vec3 eq_color = mix(vec3(0.05, 0.75, 1.0), vec3(1.0, 0.1, 0.65), smoothstep(0.1, 0.9, row));
			emission = eq_color * in_window * on * window_energy * (0.75 + peak * 1.4) * (0.8 + 0.2 * blinds);
		}
		// Світлова хвиля: кільце, що розходиться від гравця (~140 м/с) і запалює всі вікна, через які проходить.
		float d = length(world_pos.xz - beat_wave.xz);
		float ring = exp(-pow((d - beat_wave.w * 140.0) / 16.0, 2.0)) * (1.0 - smoothstep(0.5, 2.2, beat_wave.w));
		vec3 wave_color = mix(pink.rgb, cool.rgb, step(0.5, hash(cell * 5.3)));
		emission += wave_color * in_window * ring * beat_wave_strength * 3.0;
		EMISSION = emission;
	}
}
