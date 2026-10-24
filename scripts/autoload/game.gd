extends Node
## Глобальний стан гри (autoload «Game»): налаштування гонки, список гонщиків, вибір гравця.

const LAPS: int = 3
## Ботів — стільки, скільки решта гонщиків (кожен гонщик на трасі один раз), але не більше 7.
var bot_count: int:
	get:
		return mini(RACERS.size() - 1, 7)

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

var RACERS: Array[RacerData] = []
var selected_racer: RacerData


func _init() -> void:
	for path in RACER_PATHS:
		RACERS.append(load(path) as RacerData)
	selected_racer = RACERS[0]


func get_racer(racer_id: StringName) -> RacerData:
	for racer: RacerData in RACERS:
		if racer.id == racer_id:
			return racer
	return null
