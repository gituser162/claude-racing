# Технічні нотатки (для Claude)

Що важливо знати, щоб продовжити роботу над проєктом без старого контексту. Ідея гри й правила — `DESIGN.md`.

## Як влаштована робота
- **Автор не пише код** — усю роботу робить Claude; автор дає завдання поетапно й тестує. Мова спілкування й коментарів у коді — українська.
- **Проєкт** лежить на комп'ютері автора: `A:\godot\claude-racing` (зв'язок через Claude desktop app). Також є репозиторій GitHub `gituser162/claude-racing` (приватний; гілка `main`) — після кожної готової зміни комміт і push.
- **Робоча копія:** Claude працює у своїй копії (хмарне середовище), перевіряє там Godot 4.7 headless, потім записує файли в папку автора.
- **Перед записом у папку автора** — завжди: забрати свіжі копії тих самих файлів (stage), зробити diff зі своєю версією, переконатися, що відрізняються лише власні правки, і записувати з `expectedMtimeMs` (захист від затирання). Редактор Godot у автора іноді перезберігає `.tscn/.tres` (uid, порядок секцій) — свої зміни накладати на його версію, а не затирати.
- **Бінарні файли (wav, png, mp3, svg) після передачі на пристрій отримують метадані c2pa** — побайтово відрізняються, але вміст той самий; не переписувати їх без потреби.
- **Ліміт запису на пристрій — 30 МБ на файл.** Windows-збірка (~50 МБ у zip) передається через чат; **Web-збірки більше не робимо** (рішення автора) — лише Windows.
- **Збірки — лише за прямою вказівкою автора** (правило в `DESIGN.md`).
- **Тестові гонки:** якщо автор просить «не запускай тестових перегонів» — обмежитись перевіркою, що скрипти завантажуються. Тести — `tools/tests/` (див. README там).
- Субагенти, запущені у фоні, зупиняються, якщо автор перериває поточну команду — тоді доробити самому або запустити новий лише з дозволу автора.

## Архітектура (головне)
| Що | Де | Примітка |
|---|---|---|
| Глобальний стан | `scripts/autoload/game.gd` (Game) | `RACER_PATHS`/`RACERS`, `MAP_PATHS`/`MAPS`, `selected_racer`, `selected_map`, `bot_count` (1..6), `swap_in_selected_map()` |
| Звук | `scripts/autoload/audio.gd` (Audio) | словник `SFX`, шини Music/SFX, гучність і вимкнені треки в `user://settings.cfg`; плейлист `TRACKS` (load перед відтворенням), `next_track`/`prev_track`/`play_track`/`set_track_enabled`, сигнали `track_changed`, `beat(strength)`; біти — `beat_maps.gd` (генерує `tools/beat_analyze.py`), пульс → global shader uniform `beat_pulse`; живий спектр (8 смуг) → `music_bands_lo/hi`, хвиля на першій долі → `beat_wave` (xyz звідки, w час) і `beat_wave_strength`; будинки — `psx_building` (`music_eq_ratio`, для вежі `eq_base_y`/`eq_height`) (шейдери `psx` з `beat_react`, `psx_glow` з `beat_react`, `psx_building`, `hologram`, `post_psx`), повзунок «ПУЛЬС» = `beat_visuals`; плашка `scripts/ui/now_playing.gd`, рядок меню/паузи `scripts/ui/music_controls.gd`; дії `music_prev`/`music_next` ([ / ]) |
| Гонка | `scenes/main.tscn` + `scripts/main.gd` | фази, чекпоінти, місця, HUD, результати, прозорість машин, що закривають огляд (`_update_see_through`), динаміка (`RaceDynamics`) |
| Машина | `scenes/car/car.tscn` + `scripts/car/car.gd` (Car) | фізика — куля RigidBody (r 0,5) + видимий Body (top_level); курс `_heading`; занос (`drift_*`), бар'єри (`_check_barriers` контуром кузова), розворот біля стіни (`_swinging`, `_reverse_sliding`), фари, дим, іскри, `race_speed_multiplier` |
| Динаміка гонки | `scripts/race/race_dynamics.gd` | множники макс. швидкості відносно гравця: зграя, хаос, наздоганяння |
| Траса | `scripts/race/track.gd` (Track) | крива `TrackPath`, `get_transform_at(offset, lateral, height)`, `get_offset_of`, `wrap_offset`, `signed_gap` (відстань уздовж траси — для кола й спринту), `is_off_road`, `get_floor`; місто, ліхтарі, бар'єри (`barrier_mode`), арки, білборди; `elevated`, `frontage_buildings`, `keep_clear`, `menu_showcase`; тип: `closed`, `start_offset`, `finish_runout`, `finish_checkpoint`; виклик `build_features()` у дочірніх вузлах |
| Мапи | `resources/maps/*.tres` (MapData, `laps`) → `scenes/track/*.tscn` | естакада `test_track.tscn`, вулиця `city_street.tscn` (+ `street_features.gd`), спринт-вежа `spiral_tower.tscn` (+ `spiral_features.gd`); кількість кіл — `Game.laps` |
| Боти | `scripts/race/bot_driver.gd` | lookahead, безпечна швидкість за кривизною, обгін, антизастрягання, скіли |
| Зіткнення машин | `scripts/race/car_collisions.gd` | власний OBB SAT, пріоритет ваги |
| Скіли | `scripts/skills/` (Skill, SkillController, Hazard) | гонщики — `resources/racers/*.tres` + `scenes/racers/<id>/model.tscn` (див. `docs/ADDING_RACERS.md`) |
| Камера | `scripts/camera/chase_camera.gd`, `wind_effect.gd` | FOV від швидкості, трусіння (`add_shake`), вітер |
| Меню | `scenes/menu/main_menu.tscn` + `scripts/ui/main_menu.gd` | рядки RACER/MAP/BOTS/BUTTONS (`_input`), фон — траса обраної мапи |
| Шейдери | `resources/shaders/` | `psx` (усі матеріали, деталі-тексели, `see_through`), `psx_building`, `psx_glow`, `light_beam`, `hologram`, `post_psx` |

Фізичні шари: 1 world, 2 cars, 3 checkpoints, 4 skills, 5 barriers.

## Підводні камені Godot 4.7 (на яких уже обпікались)
- **`preload` у Game (autoload) → цикл залежностей** (ресурси гонщиків → скіли → Car → Game): в експорті гра не стартувала. Гонщики й мапи — шляхи + `load()` у `_init`. У скілах сцени/скрипти перешкод — `load()`, не `preload` («Parse Error: Busy»).
- **Transform3D у `.tscn` записується рядками базису**, не стовпцями.
- **Тестові `-s` скрипти** не мають статичних типів autoload-класів — брати через `root.get_node("Game")`.
- **Не можна оголошувати змінну з іменем, як у функції** того ж класу.
- **Типи з нетипізованих Dictionary:** `var x := dict[k].field` не виводиться — `var s: CarRaceState = _states[car]`.
- **`GeometryInstance3D.transparency` не діє з власним шейдером у Compatibility** → прозорість зроблена дизерингом (`see_through` у `psx.gdshader`) на власних копіях матеріалів машини. **`instance uniform` не підходить**: буфер на всі об'єкти сцени (>4096) переповнюється.
- **Сигнали зіткнень RigidBody приходять уже після удару** (швидкість у стіну погашена) — силу удару рахувати за швидкістю попереднього кадру (`_prev_velocity`); перевірку бар'єрів робити для положення після кроку фізики (`position + velocity*delta`).
- **Довга машина, що розвертається біля стіни, виштовхується** (кузов поперек стіни довший) — розворот лише коли є місце (`_has_room_to_turn`).
- **Прямі сегменти стіни на крутому повороті** різняться за кутом — тримати їх короткими (1,5 м), інакше ковзання «відштовхує».
- **Дочірні вузли отримують `_ready` раніше за батька** — особливі місця траси будуються з `Track._ready` через `build_features(track)`.
- **Шрифти в браузері:** немає системних — символи ↑↓←→▶◀■□♪✓ з `DejaVuSans-Symbols.ttf` (fallback у темі; це підмножина DejaVu Sans — новий символ додавати через `pyftsubset … --text="…"`).
- **Unshaded/additive матеріали (промені, сяйво) з туманом** додають колір туману — `fog_disabled`.
- **Перед експортом після синхронізації uid** — видалити `.godot/exported`, інакше в збірці попередження про недійсні uid.
- **Меню:** `set_input_as_handled()` викликати до зміни сцени (після — меню вже не в дереві).
- **Траса, що проходить над собою:** `CSGPolygon3D` з `PATH_ROTATION_PATH_FOLLOW` на спіралі накопичує крен (рамка без обертання) — дорога перекручується. Для таких трас `path_rotation = PATH` (переріз завжди горизонтальний). `Curve3D.get_closest_offset` — у 3D, тож на сусідніх витках (≥ 11 м) машина «чіпляється» до свого.
- **`const X = PackedFloat32Array([...])` — не константний вираз** у GDScript: великі таблиці (карти бітів) — звичайні масиви в `const`, перетворення в Packed — під час виконання. `const S: GDScript = preload(...)` втрачає члени скрипта — писати `const S := preload(...)`.
- **`RenderingServer.global_shader_parameter_get` у headless зависає** — у тестах читати значення з коду (Audio.beat_pulse).
- **Не замкнена траса:** `fposmod(offset, length)` перекидає кінець на початок — для спринту всі офсети через `Track.wrap_offset`/`signed_gap`; `CSGPolygon3D.path_joined = false`. Машина, що стоїть на самому краю кривої, скочується з плити — сітка має бути повністю на дорозі.
- **Вікна в `psx_building.gdshader`** — лише вище `ground_y + 1,5 м` (цоколь); для міста на землі нижче нуля задати `ground_y`.
- **Мережа середовища Claude:** github raw/api закриті; `git clone` працює; шаблони експорту качаються діапазонами з release-assets.

## Збірка (коли автор попросить)
```bash
rm -rf .godot/exported && G --headless --editor --quit
G --headless --export-release "Windows" export/windows/ClaudeRacing.exe
```
Шаблони — `~/.local/share/godot/export_templates/4.7.stable/` (`windows_release_x86_64*.exe`).
Перевірка: повна гонка з `--main-pack <exe>`. Web не збираємо.
