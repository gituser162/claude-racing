extends Node
## Звук (autoload «Audio»): плейлист музики, дощ і короткі ефекти.
## Музика й дощ грають безперервно між меню й гонкою.
## Шини: Music (музика), SFX (усе інше) — гучність можна міняти окремо.
##
## Музика — плейлист TRACKS у випадковому порядку (без повторів, поки не прозвучать усі увімкнені).
## Трек закінчився — наступний. [ / ] — попередній / наступний (дії music_prev / music_next).
## Які треки грають — обирає гравець (екран «ТРЕКИ» в меню), вимкнені зберігаються в settings.cfg.

signal track_changed(index: int)
## Біт музики (сила 0..1) — у момент, коли він звучить. Візуальні ефекти беруть global beat_pulse.
signal beat(strength: float)

## Карти бітів треків (згенеровані tools/beat_analyze.py): id → [час, сила, …].
const BEAT_MAPS := preload("res://scripts/autoload/beat_maps.gd")
## Як швидко згасає спалах після біта (1/с): ~0,15 с до половини.
const BEAT_DECAY: float = 7.0

## Треки: id (для налаштувань), виконавець, назва, файл і поправка гучності (дБ).
## Файли вантажаться лише перед відтворенням (load), щоб не тримати в пам'яті всі одразу.
## Новий трек — рядок тут (ogg Vorbis ~96 кбіт/с, гучність вирівняна до ~-9 LUFS; див. DESIGN.md).
const TRACKS: Array[Dictionary] = [
	{"id": &"into_the_void", "artist": "Artful", "title": "Blade x Into The Void (feat. Jordan + D'Angelo)", "path": "res://assets/audio/music/into_the_void.mp3", "gain_db": -3.0},
	{"id": &"85_again", "artist": "Robert Parker", "title": "'85 Again (feat. Miss K)", "path": "res://assets/audio/music/robert_parker_85_again.ogg", "gain_db": 0.0},
	{"id": &"ares", "artist": "Processor", "title": "A R E S", "path": "res://assets/audio/music/processor_ares.ogg", "gain_db": 0.0},
	{"id": &"bang_bang_bang", "artist": "lil yappa, BBpanzu", "title": "Bang Bang Bang (lil yappa / minus b remix)", "path": "res://assets/audio/music/lil_yappa_bang_bang_bang.ogg", "gain_db": 0.0},
	{"id": &"beware_the_beast", "artist": "Carpenter Brut, Mat McNerney", "title": "Beware The Beast", "path": "res://assets/audio/music/carpenter_brut_beware_the_beast.ogg", "gain_db": 0.0},
	{"id": &"sugarcrash", "artist": "Bemax", "title": "SugarCrash! (Bemax Remix)", "path": "res://assets/audio/music/bemax_sugarcrash.ogg", "gain_db": 0.0},
	{"id": &"caramel_jester", "artist": "UMBRELLA", "title": "CARAMEL JESTER", "path": "res://assets/audio/music/umbrella_caramel_jester.ogg", "gain_db": 0.0},
	{"id": &"division_ruine", "artist": "Carpenter Brut", "title": "Division Ruine", "path": "res://assets/audio/music/carpenter_brut_division_ruine.ogg", "gain_db": 0.0},
	{"id": &"turbo_killer", "artist": "Carpenter Brut", "title": "Turbo Killer", "path": "res://assets/audio/music/carpenter_brut_turbo_killer.ogg", "gain_db": 0.0},
	{"id": &"cry_for_me_funk", "artist": "DJ ZENKI", "title": "CRY FOR ME FUNK", "path": "res://assets/audio/music/dj_zenki_cry_for_me_funk.ogg", "gain_db": 0.0},
	{"id": &"sledge", "artist": "Dance with the Dead", "title": "Sledge", "path": "res://assets/audio/music/dance_with_the_dead_sledge.ogg", "gain_db": 0.0},
	{"id": &"hex", "artist": "Dance with the Dead", "title": "Hex", "path": "res://assets/audio/music/dance_with_the_dead_hex.ogg", "gain_db": 0.0},
]
## Явний список звуків, щоб працювало і в експорті (зокрема у браузері).
const SFX: Dictionary = {
	&"beep": preload("res://assets/audio/sfx/beep.wav"),
	&"boost": preload("res://assets/audio/sfx/boost.wav"),
	&"bump": preload("res://assets/audio/sfx/bump.wav"),
	&"chime": preload("res://assets/audio/sfx/chime.wav"),
	&"coffee": preload("res://assets/audio/sfx/coffee.wav"),
	&"engine_loop": preload("res://assets/audio/sfx/engine_loop.wav"),
	&"final_lap": preload("res://assets/audio/sfx/final_lap.wav"),
	&"finish": preload("res://assets/audio/sfx/finish.wav"),
	&"go": preload("res://assets/audio/sfx/go.wav"),
	&"hiss": preload("res://assets/audio/sfx/hiss.wav"),
	&"hit": preload("res://assets/audio/sfx/hit.wav"),
	&"honk": preload("res://assets/audio/sfx/honk.wav"),
	&"horn": preload("res://assets/audio/sfx/horn.wav"),
	&"jump": preload("res://assets/audio/sfx/jump.wav"),
	&"land": preload("res://assets/audio/sfx/land.wav"),
	&"lap": preload("res://assets/audio/sfx/lap.wav"),
	&"parcel": preload("res://assets/audio/sfx/parcel.wav"),
	&"queue": preload("res://assets/audio/sfx/queue.wav"),
	&"rain_loop": preload("res://assets/audio/sfx/rain_loop.wav"),
	&"respawn": preload("res://assets/audio/sfx/respawn.wav"),
	&"shield": preload("res://assets/audio/sfx/shield.wav"),
	&"skid_loop": preload("res://assets/audio/sfx/skid_loop.wav"),
	&"slow": preload("res://assets/audio/sfx/slow.wav"),
	&"spin": preload("res://assets/audio/sfx/spin.wav"),
	&"teleport": preload("res://assets/audio/sfx/teleport.wav"),
	&"tractor": preload("res://assets/audio/sfx/tractor.wav"),
	&"ui_move": preload("res://assets/audio/sfx/ui_move.wav"),
	&"ui_select": preload("res://assets/audio/sfx/ui_select.wav"),
	&"wind_loop": preload("res://assets/audio/sfx/wind_loop.wav"),
}

@export var music_volume_db: float = -9.0
@export var rain_volume_db: float = -20.0

const SETTINGS_PATH: String = "user://settings.cfg"

## Гучність шин 0..1 (налаштування гравця, зберігаються між запусками).
var music_level: float = 0.8
var sfx_level: float = 0.8
## Сила візуальних ефектів під біт музики 0..1 (повзунок «ПУЛЬС»; 0 — вимкнено).
var beat_visuals: float = 1.0

## Індекс треку, що грає зараз (у TRACKS), або -1.
var current_track: int = -1

var _music: AudioStreamPlayer
## Вимкнені гравцем треки (id → true).
var _disabled: Dictionary = {}
## Порядок відтворення (індекси TRACKS) і позиція в ньому; «назад» іде цим же порядком.
var _order: Array[int] = []
var _order_pos: int = -1
## Плашка «зараз грає» (показується при зміні треку).
var _now_playing: CanvasLayer
## Біти поточного треку і наступний, що ще не прозвучав.
var _beats: PackedFloat32Array = PackedFloat32Array()
var _beat_index: int = 0
## Поточний спалах під біт (0..1), згасає; іде в шейдери як global beat_pulse.
var beat_pulse: float = 0.0
var _rain: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next: int = 0
var _next_3d: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	# Петлі двигуна й дощу задані в налаштуваннях імпорту (.wav.import → loop_mode).
	# Музика зациклена в налаштуваннях імпорту (.mp3.import → loop=true).
	_music = _player(&"Music", music_volume_db)
	_music.finished.connect(next_track)
	_now_playing = load("res://scripts/ui/now_playing.gd").new()
	add_child(_now_playing)
	_reshuffle(-1)
	_play_order_pos(0, false)
	_rain = _player(&"SFX", rain_volume_db)
	_rain.stream = SFX[&"rain_loop"]
	_rain.play()
	for i: int in 10:
		_pool.append(_player(&"SFX", 0.0))
	for i: int in 16:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 10.0
		p.max_distance = 140.0
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		_pool_3d.append(p)


## Біти: порівнюємо позицію відтворення (з поправкою на затримку звуку) з картою бітів треку.
func _process(delta: float) -> void:
	beat_pulse *= exp(-BEAT_DECAY * delta)
	if _music.playing and not _beats.is_empty():
		var t := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		# Перемотали назад (трек з початку) — шукаємо місце заново.
		if _beat_index > 0 and t < _beats[(_beat_index - 1) * 2] - 0.3:
			_beat_index = _find_beat(t)
		while _beat_index * 2 < _beats.size() and _beats[_beat_index * 2] <= t:
			var strength := _beats[_beat_index * 2 + 1]
			# Пропущені біти (лаг більше 0,2 с) не спалахують усі разом.
			if t - _beats[_beat_index * 2] < 0.2:
				beat_pulse = maxf(beat_pulse, strength)
				beat.emit(strength)
			_beat_index += 1
	# Музику вимкнено повзунком — і пульсації немає.
	var visual := beat_pulse * beat_visuals * (1.0 if music_level > 0.001 else 0.0)
	RenderingServer.global_shader_parameter_set(&"beat_pulse", visual)


func _find_beat(t: float) -> int:
	var i := 0
	while i * 2 < _beats.size() and _beats[i * 2] < t:
		i += 1
	return i


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"music_next"):
		next_track()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"music_prev"):
		prev_track()
		get_viewport().set_input_as_handled()


## Показати плашку «зараз грає» з поточним треком (наприклад, на старті гонки).
func announce_current() -> void:
	_now_playing.show_track(current_track)


func track_count() -> int:
	return TRACKS.size()


## Дані треку: {id, artist, title, path, gain_db}.
func get_track(index: int) -> Dictionary:
	return TRACKS[index] if index >= 0 and index < TRACKS.size() else {}


func is_track_enabled(index: int) -> bool:
	return not _disabled.has(TRACKS[index].id)


func enabled_count() -> int:
	var count := 0
	for i: int in TRACKS.size():
		if is_track_enabled(i):
			count += 1
	return count


## Вмикає / вимикає трек. Останній увімкнений вимкнути не можна (повертає false).
## Якщо вимкнули той, що грає, — одразу наступний.
func set_track_enabled(index: int, enabled: bool) -> bool:
	if enabled == is_track_enabled(index):
		return true
	if not enabled and enabled_count() <= 1:
		return false
	if enabled:
		_disabled.erase(TRACKS[index].id)
	else:
		_disabled[TRACKS[index].id] = true
	_save_settings()
	_reshuffle(current_track)
	if not enabled and index == current_track:
		next_track()
	return true


## Наступний трек (за поточним випадковим порядком; коли всі прозвучали — новий порядок).
func next_track() -> void:
	if _order_pos + 1 >= _order.size():
		# Новий випадковий порядок; попередній трек лишаємо перед ним, щоб «назад» повертав на нього.
		var previous := current_track
		_reshuffle(-1, previous)
		if previous >= 0 and is_track_enabled(previous) and _order.size() > 1:
			_order.push_front(previous)
			_play_order_pos(1)
		else:
			_play_order_pos(0)
	else:
		_play_order_pos(_order_pos + 1)


## Попередній трек; якщо поточний грає довше 4 с — спершу з початку (як у плеєрах).
func prev_track() -> void:
	if _music.playing and _music.get_playback_position() > 4.0:
		_music.play(0.0)
		_beat_index = 0
		_now_playing.show_track(current_track)
		return
	_play_order_pos(posmod(_order_pos - 1, _order.size()))


## Грати конкретний трек зараз (з екрана «ТРЕКИ»). Вмикає його, якщо був вимкнений.
func play_track(index: int) -> void:
	set_track_enabled(index, true)
	_reshuffle(index)
	_play_order_pos(0)


## Новий випадковий порядок з увімкнених треків. first — поставити першим (якщо увімкнений),
## avoid_first — не починати з нього (щоб той самий трек не прозвучав двічі поспіль).
func _reshuffle(first: int, avoid_first: int = -1) -> void:
	_order.clear()
	for i: int in TRACKS.size():
		if is_track_enabled(i) and i != first:
			_order.append(i)
	_order.shuffle()
	if first >= 0 and is_track_enabled(first):
		_order.push_front(first)
	elif avoid_first >= 0 and _order.size() > 1 and _order[0] == avoid_first:
		_order.append(_order.pop_front())
	_order_pos = 0 if first >= 0 and is_track_enabled(first) else -1


func _play_order_pos(pos: int, announce: bool = true) -> void:
	if _order.is_empty():
		return
	_order_pos = clampi(pos, 0, _order.size() - 1)
	var index := _order[_order_pos]
	var track: Dictionary = TRACKS[index]
	var stream := load(track.path) as AudioStream
	if stream == null:
		push_error("Музика: не вдалося завантажити %s" % track.path)
		return
	current_track = index
	_beats = PackedFloat32Array(BEAT_MAPS.MAPS.get(track.id, []))
	_beat_index = 0
	_music.stream = stream
	_music.volume_db = music_volume_db + float(track.gain_db)
	_music.play()
	track_changed.emit(index)
	if announce:
		_now_playing.show_track(index)


func set_music_level(level: float) -> void:
	music_level = clampf(level, 0.0, 1.0)
	_apply_bus(&"Music", music_level)
	_save_settings()


func set_beat_visuals(level: float) -> void:
	beat_visuals = clampf(level, 0.0, 1.0)
	_save_settings()


func set_sfx_level(level: float) -> void:
	sfx_level = clampf(level, 0.0, 1.0)
	_apply_bus(&"SFX", sfx_level)
	_save_settings()


func _apply_bus(bus: StringName, level: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_level = config.get_value("audio", "music", music_level)
		sfx_level = config.get_value("audio", "sfx", sfx_level)
		beat_visuals = config.get_value("audio", "beat_visuals", beat_visuals)
		for id: Variant in config.get_value("music", "disabled", []):
			_disabled[StringName(str(id))] = true
		# Хоч один трек має грати.
		if enabled_count() == 0:
			_disabled.clear()
	_apply_bus(&"Music", music_level)
	_apply_bus(&"SFX", sfx_level)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_level)
	config.set_value("audio", "sfx", sfx_level)
	config.set_value("audio", "beat_visuals", beat_visuals)
	var disabled: PackedStringArray = []
	for id: StringName in _disabled:
		disabled.append(String(id))
	config.set_value("music", "disabled", disabled)
	config.save(SETTINGS_PATH)


## Звук «у голові» (інтерфейс, відлік, кола).
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SFX.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SFX[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Звук у точці світу (удари, скіли) — тихішає з відстанню від камери.
func play_at(sound: StringName, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SFX.has(sound):
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	p.stream = SFX[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.global_position = position
	p.play()


func get_sound(sound: StringName) -> AudioStream:
	return SFX.get(sound)


func _player(bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	return p

