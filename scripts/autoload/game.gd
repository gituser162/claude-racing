extends Node
## Глобальний стан гри (autoload «Game»): налаштування гонки, список гонщиків і мап, вибір гравця.

const LAPS: int = 3
## Ботів на трасі: щонайменше 1 і не більше, ніж решта гонщиків (кожен гонщик — один раз),
## але не більше MAX_BOTS (стільки місць у стартовій сітці й кольорів ботів).
const MIN_BOTS: int = 1
const MAX_BOTS: int = 7

## Явний список, щоб працювало і в експорті (зокрема у браузері).
## Новий гонщик — новий рядок тут (див. docs/ADDING_RACERS.md).
## Шляхи, а не preload: ресурси гонщиків тягнуть за собою скіли → Car → Game,
## і preload тут створював цикл, через який експортована гра не запускалась.
const RACER_PATHS: PackedStringArray = [
	"res://resources/racers/02_courier.tres",
	"res://resources/racers/03_office.tres",
	"res://resources/racers/04_cat.tres",
	"res://resources/racers/05_marshrutka.tres",
	"res://resources/racers/06_goose.tres",
	"res://resources/racers/07_tractor.tres",
	"res://resources/racers/08_capybara.tres",
]

## Мапи (траси) для вибору в меню. Нова мапа — новий рядок тут (див. docs/ADDING_MAPS.md).
## Теж шляхи, а не preload — з тієї ж причини, що й у гонщиків.
const MAP_PATHS: PackedStringArray = [
	"res://resources/maps/01_neon_overpass.tres",
	"res://resources/maps/02_city_street.tres",
]

var RACERS: Array[RacerData] = []
var MAPS: Array[MapData] = []
var selected_racer: RacerData
var selected_map: MapData

## Найбільша можлива кількість ботів для поточного списку гонщиків.
var max_bots: int:
	get:
		return maxi(mini(RACERS.size() - 1, MAX_BOTS), MIN_BOTS)

## Скільки ботів у гонці (обирається в меню). Значення завжди в межах MIN_BOTS..max_bots.
var bot_count: int:
	get:
		return clampi(_bot_count, MIN_BOTS, max_bots)
	set(value):
		_bot_count = clampi(value, MIN_BOTS, max_bots)

var _bot_count: int = MAX_BOTS


func _init() -> void:
	for path in RACER_PATHS:
		RACERS.append(load(path) as RacerData)
	selected_racer = RACERS[0]
	for path in MAP_PATHS:
		MAPS.append(load(path) as MapData)
	selected_map = MAPS[0]
	bot_count = max_bots


func get_racer(racer_id: StringName) -> RacerData:
	for racer: RacerData in RACERS:
		if racer.id == racer_id:
			return racer
	return null


func get_map(map_id: StringName) -> MapData:
	for map: MapData in MAPS:
		if map.id == map_id:
			return map
	return null


## Ставить трасу обраної мапи на місце вузла `old`: те саме ім'я, трансформ і позиція в дереві,
## тож код, що звертається до траси за шляхом (наприклад, $TestTrack), працює як і раніше.
## Якщо `old` — уже сцена обраної мапи, нічого не змінює й повертає `old`.
func swap_in_selected_map(old: Node3D) -> Node3D:
	if selected_map == null or selected_map.scene_path.is_empty():
		return old
	if old.scene_file_path == selected_map.scene_path:
		return old
	var scene := selected_map.load_scene()
	if scene == null:
		push_error("Мапа «%s»: не вдалося завантажити %s" % [selected_map.id, selected_map.scene_path])
		return old
	var track := scene.instantiate() as Node3D
	var parent := old.get_parent()
	var index := old.get_index()
	track.name = old.name
	track.transform = old.transform
	parent.remove_child(old)
	old.queue_free()
	parent.add_child(track)
	parent.move_child(track, index)
	return track
