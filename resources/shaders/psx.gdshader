shader_type spatial;
// Базовий матеріал у стилі «сучасний PS1» (HD-PS1):
//  - чітка геометрія в повній роздільності, без тремтіння вершин;
//  - великі «пікселі» текстур (nearest): на кожну поверхню накладається спільна
//    текстура деталей (шви панелей, заклепки, бруд) з фіксованою щільністю тексел/метр;
//  - освітлення по пікселях, м'які відблиски.
// Ім'я файлу й параметри лишились старими, щоб не міняти всі матеріали.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Сила текстури деталей (0 — гладкий колір) і скільки її текселів на метр.
uniform float detail_strength = 1.0;
uniform float texel_density = 10.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
// Застарілі параметри PS1-стилю (тремтіння, афінні UV) — більше не діють.
uniform vec2 snap_grid = vec2(0.0);
uniform float affine_strength = 0.0;

global uniform sampler2D psx_detail : filter_nearest_mipmap, repeat_enable;
// Пульс під біт музики (0..1, ставить Audio) і наскільки цей матеріал на нього реагує (неон — 1).
global uniform float beat_pulse;
uniform float beat_react = 0.0;
// «Сітчаста» прозорість (0 — звичайний, 1 — невидимий): частина пікселів відкидається
// за шаблоном Баєра, як на старих консолях. Напр. машина, що закриває камері гравця
// (див. Car.set_see_through — машина отримує власні копії матеріалів).
uniform float see_through = 0.0;

const float BAYER4[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	// Координати в системі об'єкта, але в метрах (з урахуванням масштабу) —
	// так тексели однакового розміру на всіх деталях і не «пливуть», коли машина рухається.
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - MODEL_MATRIX[3].xyz;
	local_pos = vec3(dot(p, normalize(MODEL_MATRIX[0].xyz)),
			dot(p, normalize(MODEL_MATRIX[1].xyz)),
			dot(p, normalize(MODEL_MATRIX[2].xyz)));
	local_normal = NORMAL;
}

void fragment() {
	if (see_through > 0.0) {
		ivec2 cell = ivec2(FRAGCOORD.xy / 2.0) % 4;
		if ((BAYER4[cell.y * 4 + cell.x] + 0.5) / 16.0 < see_through) {
			discard;
		}
	}
	vec3 color = albedo.rgb * texture(albedo_texture, UV * uv_scale).rgb;
	if (detail_strength > 0.0) {
		vec3 n = abs(local_normal);
		vec2 uv = n.x > n.y && n.x > n.z ? local_pos.zy : (n.y > n.z ? local_pos.xz : local_pos.xy);
		vec3 d = texture(psx_detail, uv * texel_density / 64.0).rgb * 2.0;
		color *= mix(vec3(1.0), d, detail_strength);
	}
	ALBEDO = color;
	// Неон «дихає» з музикою: між бітами трохи тьмяніший, на біті — яскравий спалах.
	EMISSION = emission.rgb * emission_energy * (1.0 + beat_react * (beat_pulse * 1.6 - 0.3));
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
}
