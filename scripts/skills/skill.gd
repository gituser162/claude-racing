class_name Skill
extends Node
## Базовий скіл. Кожен конкретний скіл — окремий скрипт, що успадковує цей
## і перевизначає _activate() (що робить) і bot_wants_to_use() (коли його вмикає бот).
## Екземпляр скіла створюється для кожної машини окремо (SkillController).
## Інструкція з прикладами: docs/ADDING_RACERS.md.

## Перезарядка, с (для ультімейта не використовується — він одноразовий).
@export var cooldown: float = 8.0
## Звук при активації (назва з Audio.SFX, напр. &"boost"). Порожньо — без звуку.
@export var sound: StringName = &""
## Гучність звуку скіла, дБ (від'ємне — тихіше).
@export var sound_volume_db: float = 0.0

var car: Car
var is_ultimate: bool = false
var cooldown_left: float = 0.0
var used: bool = false


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


## Чи можна застосувати прямо зараз (без урахування загальних блокувань гонки).
func is_ready() -> bool:
	if is_ultimate and used:
		return false
	return cooldown_left <= 0.0 and _can_use()


func activate() -> bool:
	if not is_ready():
		return false
	_activate()
	if sound != &"":
		Audio.play_at(sound, car.body.global_position, sound_volume_db + (0.0 if car.controlled_by_player else -3.0))
	used = true
	if not is_ultimate:
		cooldown_left = cooldown
	return true


## Додаткові умови конкретного скіла (наприклад, стрибок — лише з землі).
func _can_use() -> bool:
	return true


func _activate() -> void:
	pass


## Чи хоче бот застосувати скіл зараз. Викликається, лише коли скіл готовий.
func bot_wants_to_use(_driver: BotDriver) -> bool:
	return false


# ---------------------------------------------------------------------------
# Помічники для скілів. Використовуйте їх у _activate() і bot_wants_to_use().
# ---------------------------------------------------------------------------

func get_track() -> Track:
	return car.skills.track


## Усі машини гонки, крім своєї.
func other_cars() -> Array[Car]:
	var result: Array[Car] = []
	for other: Car in car.skills.cars:
		if other != car:
			result.append(other)
	return result


## Найближча машина попереду вздовж траси (не далі max_distance м), або null.
func car_ahead(max_distance: float = 80.0) -> Car:
	return _nearest_along_track(max_distance, true)


## Найближча машина позаду вздовж траси (не далі max_distance м), або null.
func car_behind(max_distance: float = 80.0) -> Car:
	return _nearest_along_track(max_distance, false)


## Усі суперники в радіусі radius м навколо машини.
func cars_within(radius: float) -> Array[Car]:
	var result: Array[Car] = []
	var pos := car.body.global_position
	for other: Car in other_cars():
		if other.body.global_position.distance_to(pos) <= radius:
			result.append(other)
	return result


## Усі суперники попереду вздовж траси в межах distance м.
func cars_ahead_within(distance: float) -> Array[Car]:
	var result: Array[Car] = []
	for other: Car in other_cars():
		var d := _track_distance(other)
		if d > 0.0 and d <= distance:
			result.append(other)
	return result


## Ставить перешкоду/снаряд (сцену з коренем Hazard або будь-яким Node3D) у світ гонки.
## Сцени для цього завантажуйте через load() у самому скілі, а не preload()
## (preload створює циклічну залежність скриптів і помилку «Busy» при завантаженні).
func spawn_in_world(scene: PackedScene, where: Transform3D) -> Node3D:
	var node: Node3D = scene.instantiate()
	# Без прямого посилання на клас Hazard — щоб не було циклічних залежностей скриптів.
	if "source_car" in node:
		node.source_car = car
	car.get_parent().add_child(node)
	node.global_transform = where
	return node


## Точка на дорозі позаду машини (для «скинути щось позаду»).
func transform_behind(distance: float = 4.0) -> Transform3D:
	var t := Transform3D(Basis(Vector3.UP, atan2(-car.get_forward().x, -car.get_forward().z)), car.body.global_position)
	t.origin -= car.get_forward() * distance
	return t


## Відстань уздовж траси від своєї машини до іншої (+ попереду, − позаду).
func _track_distance(other: Car) -> float:
	var track := get_track()
	if track == null:
		return 0.0
	var mine := track.get_offset_of(car.body.global_position)
	var theirs := track.get_offset_of(other.body.global_position)
	var d := fposmod(theirs - mine, track.length)
	return d if d <= track.length * 0.5 else d - track.length


func _nearest_along_track(max_distance: float, ahead: bool) -> Car:
	var best: Car = null
	var best_d := max_distance
	for other: Car in other_cars():
		var d := _track_distance(other)
		if not ahead:
			d = -d
		if d > 0.0 and d < best_d:
			best_d = d
			best = other
	return best
