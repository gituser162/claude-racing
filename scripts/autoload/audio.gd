extends Node
## Звук (autoload «Audio»): фонова музика, дощ і короткі ефекти.
## Музика й дощ грають безперервно між меню й гонкою.
## Шини: Music (музика), SFX (усе інше) — гучність можна міняти окремо.

const MUSIC: AudioStream = preload("res://assets/audio/music/into_the_void.mp3")
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
	&"slow": preload("res://assets/audio/sfx/slow.wav"),
	&"spin": preload("res://assets/audio/sfx/spin.wav"),
	&"teleport": preload("res://assets/audio/sfx/teleport.wav"),
	&"tractor": preload("res://assets/audio/sfx/tractor.wav"),
	&"ui_move": preload("res://assets/audio/sfx/ui_move.wav"),
	&"ui_select": preload("res://assets/audio/sfx/ui_select.wav"),
}

@export var music_volume_db: float = -9.0
@export var rain_volume_db: float = -20.0

const SETTINGS_PATH: String = "user://settings.cfg"

## Гучність шин 0..1 (налаштування гравця, зберігаються між запусками).
var music_level: float = 0.8
var sfx_level: float = 0.8

var _music: AudioStreamPlayer
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
	_music.stream = MUSIC
	_music.play()
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


func set_music_level(level: float) -> void:
	music_level = clampf(level, 0.0, 1.0)
	_apply_bus(&"Music", music_level)
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
	_apply_bus(&"Music", music_level)
	_apply_bus(&"SFX", sfx_level)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_level)
	config.set_value("audio", "sfx", sfx_level)
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

