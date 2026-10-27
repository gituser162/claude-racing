extends Node3D
## Гонка: відлік на старті, гравець + боти, кола, місця, час, фініш і таблиця результатів.

const CAR_SCENE: PackedScene = preload("res://scenes/car/car.tscn")
## Кольори ботів (поки всі боти — копії гравцевого гонщика іншого кольору).
const BOT_COLORS: Array[Color] = [
	Color(0.15, 0.75, 0.85), Color(0.9, 0.75, 0.15), Color(0.55, 0.3, 0.85),
	Color(0.85, 0.85, 0.9), Color(0.25, 0.7, 0.3), Color(0.9, 0.45, 0.1),
	Color(0.85, 0.3, 0.6),
]
## Стартова сітка: ряди по дві машини, перший ряд за 8 м від лінії, далі кожні 6 м.
const GRID_FIRST_ROW: float = 8.0
const GRID_ROW_STEP: float = 6.0
const GRID_LATERAL: float = 3.0
enum Phase { COUNTDOWN, RACING }

## Тривалість відліку 3-2-1 перед стартом, с.
const COUNTDOWN_TIME: float = 3.0
## Скільки секунд гравець має їхати не в той бік, щоб з'явилось попередження.
const WRONG_WAY_DELAY: float = 0.8
## Скільки секунд після старту скіли заблоковані.
const SKILL_START_LOCK: float = 3.0
## Тимчасово, поки гонщик один: боти різної ваги, щоб відчути зіткнення.
## Порядок як у BOT_COLORS: бірюзовий, жовтий, фіолетовий, білий, зелений, помаранчевий, рожевий.
const BOT_WEIGHTS: Array[int] = [3, 1, 2, 3, 1, 2, 3]

@onready var _track: Track = $TestTrack
@onready var _car: Car = $Car
@onready var _message: Label = $UI/Message
@onready var _wrong_way_label: Label = $UI/WrongWay
@onready var _place_num: Label = $UI/TopLeft/VBox/PlaceRow/PlaceNum
@onready var _place_total: Label = $UI/TopLeft/VBox/PlaceRow/PlaceOf
@onready var _lap_label: Label = $UI/TopLeft/VBox/Lap
@onready var _times_label: Label = $UI/TopLeft/VBox/Times
@onready var _standings_text: RichTextLabel = $UI/Standings/Text
@onready var _speed_num: Label = $UI/SpeedBox/SpeedNum
@onready var _speed_bar: ProgressBar = $UI/SpeedBox/SpeedBar
@onready var _skills_box: Control = $UI/Skills
@onready var _skill_q_panel: PanelContainer = $UI/Skills/SkillQ
@onready var _skill_q_name: Label = $UI/Skills/SkillQ/VBox/Name
@onready var _skill_q_status: Label = $UI/Skills/SkillQ/VBox/Status
@onready var _skill_q_bar: ProgressBar = $UI/Skills/SkillQ/VBox/Bar
@onready var _skill_e_panel: PanelContainer = $UI/Skills/SkillE
@onready var _skill_e_name: Label = $UI/Skills/SkillE/VBox/Name
@onready var _skill_e_status: Label = $UI/Skills/SkillE/VBox/Status
@onready var _skill_e_bar: ProgressBar = $UI/Skills/SkillE/VBox/Bar
@onready var _results_panel: PanelContainer = $UI/Results
@onready var _results_text: RichTextLabel = $UI/Results/Text

var _race_time: float = 0.0
var _cars: Array[Car] = []
var _states: Dictionary = {}   # Car -> CarRaceState
var _drivers: Dictionary = {}  # Car -> BotDriver
var _finish_order: Array[Car] = []
var _message_timer: float = 0.0
var _phase: Phase = Phase.COUNTDOWN
var _countdown_left: float = COUNTDOWN_TIME
var _last_countdown_number: int = 0
var _wrong_way_time: float = 0.0
## Прихована динаміка гонки навколо гравця (див. scripts/race/race_dynamics.gd).
var _dynamics := RaceDynamics.new()
var _bot_racers: Array[RacerData] = []


class CarRaceState:
	var lap: int = 1
	var next_checkpoint: int = 1   # лінію старту (0) вважаємо пройденою на старті
	var checkpoints_this_lap: int = 0
	var lap_start_time: float = 0.0
	var last_lap: float = -1.0
	var best_lap: float = -1.0
	var finished: bool = false
	var finish_time: float = 0.0


## Траса обраної мапи стає на місце $TestTrack одразу після створення сцени —
## ще до входу в дерево й до @onready, тож усе далі працює з потрібною трасою.
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		Game.swap_in_selected_map($TestTrack)


func _ready() -> void:
	_track.checkpoint_passed.connect(_on_checkpoint_passed)
	_car.enable_headlight_light()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var slots := Game.bot_count + 1
	_bot_racers = _pick_bot_racers(Game.bot_count, rng)
	var bot_index := 0
	for slot: int in slots:
		var car: Car
		if slot == slots - 1:   # гравець стартує останнім
			car = _car
		else:
			car = _spawn_bot(bot_index)
			bot_index += 1
		car.teleport(_grid_transform(slot))
		car.fall_limit_y = _track.fall_limit_y
		_cars.append(car)
		_states[car] = CarRaceState.new()
		# Скіли заблоковані на час відліку і ще кілька секунд після старту.
		car.skills.lock_for(COUNTDOWN_TIME + SKILL_START_LOCK)
		# Гонка в одне коло (спринт) — це вже останнє коло: ультімейт доступний одразу.
		if Game.laps == 1:
			car.skills.unlock_ultimate()
	for car: Car in _cars:
		car.skills.set_race(_cars, _track)
	for car: Car in _drivers:
		var driver: BotDriver = _drivers[car]
		driver.setup(car, _track, _cars, rng)
		driver.skill = rng.randf_range(0.88, 0.97)
	var collisions := CarCollisions.new()
	collisions.name = "CarCollisions"
	collisions.cars = _cars
	add_child(collisions)
	collisions.bumped.connect(_on_bumped)
	$ChaseCamera.snap()
	# До кінця відліку ніхто не їде.
	_set_cars_enabled(false)
	_results_panel.visible = false
	_wrong_way_label.visible = false


func _on_bumped(a: Car, b: Car, strength: float) -> void:
	var where := (a.body.global_position + b.body.global_position) * 0.5
	Audio.play_at(&"bump", where, linear_to_db(clampf(strength / 12.0, 0.15, 1.0)))
	if a == _car or b == _car:
		$ChaseCamera.add_shake(clampf(strength / 20.0, 0.15, 0.7))


func _set_cars_enabled(enabled: bool) -> void:
	for car: Car in _cars:
		if _drivers.has(car):
			_drivers[car].active = enabled
		else:
			car.controlled_by_player = enabled
		if not enabled:
			car.throttle_input = 0.0
			car.steer_input = 0.0


func _start_race() -> void:
	_phase = Phase.RACING
	_race_time = 0.0
	_set_cars_enabled(true)
	_show_message("СТАРТ!", 1.0)
	Audio.play(&"go")


func _update_countdown(delta: float) -> void:
	_countdown_left -= delta
	var number := ceili(_countdown_left)
	if number != _last_countdown_number and number > 0:
		_last_countdown_number = number
		_show_message(str(number), 1.0)
		Audio.play(&"beep")
	if _countdown_left <= 0.0:
		_start_race()


func _spawn_bot(index: int) -> Car:
	var car: Car = CAR_SCENE.instantiate()
	car.racer = _bot_racer(index)
	car.controlled_by_player = false
	car.name = "Bot%d" % (index + 1)
	add_child(car)
	var driver := BotDriver.new()
	driver.name = "BotDriver"
	car.add_child(driver)
	_drivers[car] = driver
	return car


## Які гонщики стануть ботами: усі з Game.RACERS, крім обраного гравцем, без повторів.
## Якщо ботів менше, ніж гонщиків, — випадкові з них (у порядку Game.RACERS).
func _pick_bot_racers(count: int, rng: RandomNumberGenerator) -> Array[RacerData]:
	var pool: Array[RacerData] = []
	for racer: RacerData in Game.RACERS:
		if racer != Game.selected_racer:
			pool.append(racer)
	if count >= pool.size():
		return pool
	var indices: Array[int] = []
	indices.assign(range(pool.size()))
	# Тасування Фішера — Єйтса тим самим rng, що й у ботів.
	for i: int in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var chosen := indices.slice(0, count)
	chosen.sort()
	var result: Array[RacerData] = []
	for i: int in chosen:
		result.append(pool[i])
	return result


## Гонщик для бота: з відібраних _pick_bot_racers.
## Поки гонщик лише один — копія гравцевого іншого кольору й ваги.
func _bot_racer(index: int) -> RacerData:
	if not _bot_racers.is_empty():
		return _bot_racers[index % _bot_racers.size()]
	var data: RacerData = Game.selected_racer.duplicate()
	data.car_color = BOT_COLORS[index % BOT_COLORS.size()]
	data.weight = BOT_WEIGHTS[index % BOT_WEIGHTS.size()]
	data.display_name = "Бот %d" % (index + 1)
	return data


func _grid_transform(slot: int) -> Transform3D:
	var back := GRID_FIRST_ROW + (slot / 2) * GRID_ROW_STEP
	var lateral := -GRID_LATERAL if slot % 2 == 0 else GRID_LATERAL
	# Сітка стоїть позаду лінії старту: на колі — у кінці кривої, на спринті — перед start_offset.
	var line := _track.length if _track.closed else _track.start_offset
	return _track.get_transform_at(line - back, lateral)


func _physics_process(delta: float) -> void:
	if _phase == Phase.COUNTDOWN:
		_update_countdown(delta)
		return
	_race_time += delta
	_check_wrong_way(delta)
	_check_off_road()
	_dynamics.update(delta, _cars, _car, _progress, _is_finished)


## Машини між камерою й машиною гравця стають напівпрозорими, щоб велика модель
## (фургон, маршрутка, трактор) не закривала маленького гонщика й трасу.
const SEE_THROUGH_AMOUNT: float = 0.65
const SEE_THROUGH_SPEED: float = 6.0


func _update_see_through(delta: float) -> void:
	var camera: Camera3D = $ChaseCamera
	var from := camera.global_position
	var to := _car.body.global_position + Vector3.UP * 0.8
	var line := to - from
	var length_sq := maxf(line.length_squared(), 0.01)
	for car: Car in _cars:
		if car == _car:
			continue
		var pos := car.body.global_position + Vector3.UP * 0.8
		var t := clampf((pos - from).dot(line) / length_sq, 0.0, 1.0)
		var closest := from + line * t
		# Радіус «загородження» — половина більшого розміру моделі плюс запас.
		var radius := maxf(car.footprint.x, car.footprint.y) * 0.5 + 0.4
		# Між камерою й гравцем — або камера взагалі всередині цієї машини.
		var blocking := t < 1.0 and pos.distance_to(closest) < radius
		var target := SEE_THROUGH_AMOUNT if blocking else 0.0
		car.set_see_through(move_toward(car._see_through, target, SEE_THROUGH_SPEED * delta))


func _is_finished(car: Car) -> bool:
	var state: CarRaceState = _states[car]
	return state.finished


## Машина вилетіла за відбійник у прірву (траси з respawn_off_road) — одразу на останній чекпоінт,
## не чекаючи, поки вона впаде до fall_limit_y.
func _check_off_road() -> void:
	if not _track.respawn_off_road:
		return
	for car: Car in _cars:
		if not _states[car].finished and _track.is_off_road(car.ball.global_position):
			car.respawn()


## «Не той бік»: гравець їде проти напрямку траси.
func _check_wrong_way(delta: float) -> void:
	var state: CarRaceState = _states[_car]
	var offset := _track.get_offset_of(_car.body.global_position)
	var track_dir := -_track.get_transform_at(offset).basis.z
	var backwards := not state.finished and _car.get_forward().dot(track_dir) < -0.3 \
		and _car.ball.linear_velocity.dot(track_dir) < -3.0
	_wrong_way_time = _wrong_way_time + delta if backwards else 0.0
	_wrong_way_label.visible = _wrong_way_time > WRONG_WAY_DELAY and fmod(_race_time, 0.6) < 0.4


func _process(delta: float) -> void:
	_update_hud()
	_update_see_through(delta)
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""


func _unhandled_input(event: InputEvent) -> void:
	var state: CarRaceState = _states[_car]
	if not state.finished:
		return
	if event.is_action_pressed(&"respawn"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed(&"ui_accept") and _results_panel.visible:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_checkpoint_passed(car: Car, index: int) -> void:
	var state: CarRaceState = _states.get(car)
	if state == null or state.finished:
		return
	# Приймаємо наступний чекпоінт або один-два далі (якщо зрізав і пропустив).
	var ahead := posmod(index - state.next_checkpoint, _track.checkpoint_count)
	if ahead > 2:
		return
	state.next_checkpoint = (index + 1) % _track.checkpoint_count
	state.checkpoints_this_lap += 1
	car.set_respawn_point(_track.get_checkpoint_transform(index))
	if index == _track.finish_checkpoint:
		_complete_lap(car, state)


func _complete_lap(car: Car, state: CarRaceState) -> void:
	var lap_time := _race_time - state.lap_start_time
	state.last_lap = lap_time
	if state.best_lap < 0.0 or lap_time < state.best_lap:
		state.best_lap = lap_time
	if state.lap >= Game.laps:
		_finish(car, state)
		return
	state.lap += 1
	state.checkpoints_this_lap = 0
	state.lap_start_time = _race_time
	if state.lap == Game.laps:
		car.skills.unlock_ultimate()
	if car == _car:
		Audio.play(&"final_lap" if state.lap == Game.laps else &"lap")
		var text := "ОСТАННЄ КОЛО!\nУльтімейт [E] готовий" if state.lap == Game.laps else "Коло %d" % state.lap
		_show_message("%s\n%s" % [text, _format_time(lap_time)], 2.5)


func _finish(car: Car, state: CarRaceState) -> void:
	state.finished = true
	state.finish_time = _race_time
	_finish_order.append(car)
	if _drivers.has(car):
		if _track.closed:
			_drivers[car].active = false
		else:
			# Спринт: за фінішем траса закінчується — бот гальмує в зоні за фінішем.
			_drivers[car].brake_to_stop = true
	else:
		# Гравець фінішував: машину далі веде автопілот, показуємо результати.
		car.controlled_by_player = false
		var autopilot := BotDriver.new()
		autopilot.name = "Autopilot"
		car.add_child(autopilot)
		autopilot.setup(car, _track, _cars, RandomNumberGenerator.new())
		autopilot.skill = 0.8
		autopilot.brake_to_stop = not _track.closed
		_show_message("ФІНІШ!  %d місце" % _finish_order.size(), 2.5)
		Audio.play(&"finish")
		get_tree().create_timer(2.5).timeout.connect(_show_results)


## Скільки пройдено від старту гонки (у метрах) — для визначення місць.
func _progress(car: Car) -> float:
	var state: CarRaceState = _states[car]
	var offset := _track.get_offset_of(car.body.global_position)
	if not _track.closed:
		return offset - _track.start_offset
	# На старті машина стоїть за лінією, тобто «в кінці» кривої — це ще до старту.
	if state.checkpoints_this_lap == 0 and offset > _track.length * 0.5:
		offset -= _track.length
	return (state.lap - 1) * _track.length + offset


## Місце машини: спершу фінішували (за порядком), далі — хто далі проїхав.
func _place_of(car: Car) -> int:
	var finished_index := _finish_order.find(car)
	if finished_index >= 0:
		return finished_index + 1
	var my_progress := _progress(car)
	var place := _finish_order.size() + 1
	for other: Car in _cars:
		if other != car and not _states[other].finished and _progress(other) > my_progress:
			place += 1
	return place


func _show_message(text: String, duration: float) -> void:
	_message.text = text
	_message_timer = duration


func _update_hud() -> void:
	var state: CarRaceState = _states[_car]
	var order := _current_order()
	var time := state.finish_time if state.finished else _race_time
	if _phase == Phase.COUNTDOWN:
		time = 0.0
	var lap_time := 0.0 if state.finished or _phase == Phase.COUNTDOWN else _race_time - state.lap_start_time
	_place_num.text = str(order.find(_car) + 1)
	_place_total.text = "/%d" % _cars.size()
	if _track.floor_height > 0.0:
		# Вежа: замість кола — поверх, на якому зараз гравець.
		var floor_number := _track.get_floor(_car.body.global_position)
		var top := _track.get_floor(_track.get_transform_at(0.0).origin)
		_lap_label.text = "ДАХ" if floor_number >= top else "ПОВЕРХ %d" % floor_number
	else:
		_lap_label.text = "КОЛО %d/%d" % [mini(state.lap, Game.laps), Game.laps]
	if Game.laps == 1:
		_times_label.text = "ЧАС  %s" % _format_time(time)
	else:
		_times_label.text = "ЧАС  %s\nКОЛО  %s\nКРАЩЕ  %s" % [
			_format_time(time), _format_time(lap_time),
			_format_time(state.best_lap) if state.best_lap >= 0.0 else "—"]
	var kmh := absf(_car.get_speed()) * 3.6
	_speed_num.text = str(roundi(kmh))
	_speed_bar.value = clampf(kmh / 180.0, 0.0, 1.0)
	_update_skill_hud()
	_update_standings(order)
	if _results_panel.visible:
		_update_results(order)


## Машини в порядку поточних місць: спершу фінішували (за порядком), далі — хто далі проїхав.
func _current_order() -> Array[Car]:
	var order: Array[Car] = _finish_order.duplicate()
	var racing: Array[Car] = []
	var progress: Dictionary = {}
	for car: Car in _cars:
		if not _states[car].finished:
			racing.append(car)
			progress[car] = _progress(car)
	racing.sort_custom(func(a: Car, b: Car) -> bool: return progress[a] > progress[b])
	order.append_array(racing)
	return order


func _display_name(car: Car) -> String:
	return "ТИ" if car == _car else car.racer.display_name


func _update_standings(order: Array[Car]) -> void:
	var lines: PackedStringArray = []
	for i: int in order.size():
		var car := order[i]
		if car == _car:
			lines.append("[color=#ff4dd2]▶ %d. %s[/color]" % [i + 1, _display_name(car)])
		else:
			lines.append("[color=#5ff2ff]%d.[/color] %s" % [i + 1, _display_name(car)])
	_standings_text.text = "\n".join(lines)


func _show_results() -> void:
	_results_panel.visible = true
	_skills_box.visible = false


func _update_results(order: Array[Car]) -> void:
	# В гонці на одне коло «краще коло» = загальний час — цю колонку не показуємо.
	var one_lap := Game.laps == 1
	# Типізований масив не можна присвоїти з тернарного виразу (там звичайний Array) — будуємо додаванням.
	var headers: Array[String] = ["#", "ГОНЩИК", "ЧАС"]
	if not one_lap:
		headers.append("КРАЩЕ КОЛО")
	var rows: PackedStringArray = ["[font_size=20][color=#ff4dd2]РЕЗУЛЬТАТИ[/color][/font_size]\n", "[table=%d]" % headers.size()]
	for header: String in headers:
		rows.append("[cell][color=#5ff2ff]%s[/color]  [/cell]" % header)
	for i: int in order.size():
		var car := order[i]
		var state: CarRaceState = _states[car]
		var time := _format_time(state.finish_time) if state.finished else "у гонці"
		var best := _format_time(state.best_lap) if state.best_lap >= 0.0 else "—"
		var color := "#ff4dd2" if car == _car else "#e0dcf2"
		var cells: Array[String] = [str(i + 1), _display_name(car), time]
		if not one_lap:
			cells.append(best)
		for cell: String in cells:
			rows.append("[cell][color=%s]%s[/color]  [/cell]" % [color, cell])
	rows.append("[/table]")
	rows.append("\n[color=#5ff2ff]R[/color] — ще раз        [color=#5ff2ff]ENTER[/color] — меню")
	_results_text.text = "".join(rows)


func _update_skill_hud() -> void:
	var skills := _car.skills
	# Q: блок на старті / перезарядка / готово.
	var q_status := "—"
	var q_fill := 0.0
	if skills.q:
		if skills.is_locked():
			q_status = "%.0f с" % ceilf(skills.lock_left())
		elif skills.q.cooldown_left > 0.0:
			q_status = "%.1f с" % skills.q.cooldown_left
			q_fill = 1.0 - skills.q.cooldown_left / skills.q.cooldown
		else:
			q_status = "ГОТОВО"
			q_fill = 1.0
	_skill_q_name.text = "[Q] %s" % skills.q_name
	_skill_q_status.text = q_status
	_skill_q_bar.value = q_fill
	_set_skill_style(_skill_q_panel, skills.can_use_q())
	# E: ультімейт — закритий до останнього кола, потім готовий або використаний.
	var e_status := "—"
	if skills.e:
		if skills.e.used:
			e_status = "ВИКОРИСТАНО"
		elif not skills.is_ultimate_unlocked():
			e_status = "останнє коло"
		elif skills.is_locked():
			e_status = "%.0f с" % ceilf(skills.lock_left())
		else:
			e_status = "ГОТОВО" if skills.e.is_ready() else "у повітрі"
	_skill_e_name.text = "[E] %s" % skills.e_name
	_skill_e_status.text = e_status
	_skill_e_bar.value = 1.0 if skills.can_use_e() else 0.0
	_set_skill_style(_skill_e_panel, skills.can_use_e())


func _set_skill_style(panel: PanelContainer, ready: bool) -> void:
	panel.theme_type_variation = &"SkillReady" if ready else &"SkillIdle"
	panel.modulate = Color(1, 1, 1, 1) if ready else Color(0.75, 0.72, 0.8, 0.9)


static func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d:%05.2f" % [minutes, seconds - minutes * 60]
