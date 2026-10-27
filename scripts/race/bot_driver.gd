class_name BotDriver
extends Node
## Штучний водій. Додається дочірнім вузлом до машини-бота й щокадру
## виставляє їй throttle_input / steer_input.
## Їде вздовж центральної кривої траси зі своєю «смугою», гальмує перед поворотами,
## об'їжджає машини попереду і респавниться, якщо застряг.

## Частка максимальної швидкості, з якою бот готовий їхати (0.85–1.0).
@export var skill: float = 0.93
## Наскільки обережно бот входить у повороти (менше — гальмує раніше).
@export var corner_caution: float = 0.85

const LANE_LIMIT: float = 5.0
const BRAKE_FOR_PLANNING: float = 18.0

var active: bool = true
var car: Car
var track: Track
var others: Array[Car] = []

var _base_lane: float = 0.0
var _lane: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _stuck_time: float = 0.0
var _last_safe_speed: float = 0.0
var _ahead_distance: float = INF
var _overtake_time: float = 0.0
var _overtake_lane: float = 0.0


func setup(p_car: Car, p_track: Track, p_others: Array[Car], rng: RandomNumberGenerator) -> void:
	car = p_car
	track = p_track
	others = p_others
	car.controlled_by_player = false
	_base_lane = rng.randf_range(-2.5, 2.5)
	_lane = _base_lane
	_phase = rng.randf() * TAU


func _physics_process(delta: float) -> void:
	if car == null:
		return
	if not active:
		car.throttle_input = 0.0
		car.steer_input = 0.0
		return
	_time += delta
	var pos := car.body.global_position
	var speed := car.get_speed()
	var offset := track.get_offset_of(pos)

	_update_lane(pos, delta)

	# Кермо: ціль на центрі «смуги» трохи попереду, чим швидше — тим далі.
	var look := 7.0 + absf(speed) * 0.45
	var target := track.get_transform_at(offset + look, _lane).origin
	var to_target := target - pos
	var forward := car.get_forward()
	var angle := atan2(forward.cross(to_target).y, forward.dot(to_target))
	car.steer_input = clampf(angle * 2.5, -1.0, 1.0)

	# Газ/гальмо: тримаємо безпечну швидкість для поворотів попереду.
	var target_speed := _safe_speed(offset)
	_last_safe_speed = target_speed
	if car.is_boosting() and is_on_straight():
		target_speed = INF   # під турбо на прямій не гальмуємо
	if speed < target_speed - 1.0:
		car.throttle_input = 1.0
	elif speed > target_speed + 3.0:
		car.throttle_input = -1.0
	else:
		car.throttle_input = 0.3

	_use_skills()
	_check_stuck(speed, delta)


## Попереду пряма (найближчі ~70 м без поворотів, що потребують гальмування).
func is_on_straight() -> bool:
	return _last_safe_speed >= car.max_speed * car.race_speed_multiplier * skill * 0.98


## Відстань до найближчої машини попереду в нашій смузі (INF, якщо нікого).
func car_ahead_distance() -> float:
	return _ahead_distance


func _use_skills() -> void:
	var skills := car.skills
	if skills == null:
		return
	if skills.can_use_q() and skills.q.bot_wants_to_use(self):
		skills.use_q()
	if skills.can_use_e() and skills.e.bot_wants_to_use(self):
		skills.use_e()


## Плавно «гуляє» по ширині дороги, а якщо попереду в смузі хтось повільніший —
## обганяє: обирає вільніший бік і тримається його, доки не пройде.
func _update_lane(pos: Vector3, delta: float) -> void:
	var wanted := _base_lane + sin(_time * 0.25 + _phase) * 1.5
	var forward := car.get_forward()
	var right := forward.cross(Vector3.UP)
	_ahead_distance = INF
	var blocker: Car = null
	var blocker_side := 0.0
	for other: Car in others:
		if other == car:
			continue
		var rel := other.body.global_position - pos
		var ahead := rel.dot(forward)
		var side := rel.dot(right)
		var clearance := (other.footprint.x + car.footprint.x) * 0.5 + 0.6
		if ahead > 0.0 and absf(side) < clearance:
			_ahead_distance = minf(_ahead_distance, ahead)
			if ahead < 22.0 and (blocker == null or ahead < blocker.body.global_position.distance_to(pos)):
				blocker = other
				blocker_side = side
	if blocker:
		_overtake_time = 1.5
		var pass_offset := (blocker.footprint.x + car.footprint.x) * 0.5 + 1.2
		# Обганяємо з того боку, де до краю дороги більше місця.
		var go_left := _lane - blocker_side * 0.0 > 0.0 if absf(blocker_side) < 0.3 else blocker_side > 0.0
		_overtake_lane = _lane + blocker_side + (-pass_offset if go_left else pass_offset)
	if _overtake_time > 0.0:
		_overtake_time -= delta
		wanted = _overtake_lane
	wanted = clampf(wanted, -LANE_LIMIT, LANE_LIMIT)
	_lane = move_toward(_lane, wanted, 5.0 * delta)


## Максимальна швидкість, з якою можна їхати зараз, щоб встигнути загальмувати
## перед найкрутішим поворотом попереду.
func _safe_speed(offset: float) -> float:
	var limit := car.max_speed * car.race_speed_multiplier * skill
	var yaw_rate := car.turn_speed * lerpf(1.0, car.high_speed_turn_factor, 0.8) * corner_caution
	var segment := 8.0
	var prev_dir := _track_dir(offset)
	var distance := segment
	while distance <= 72.0:
		var dir := _track_dir(offset + distance)
		var turn := absf(atan2(prev_dir.cross(dir).y, prev_dir.dot(dir)))
		if turn > 0.001:
			var radius := segment / turn
			var corner_speed := yaw_rate * radius
			var allowed := sqrt(corner_speed * corner_speed + 2.0 * BRAKE_FOR_PLANNING * maxf(distance - segment, 0.0))
			limit = minf(limit, allowed)
		prev_dir = dir
		distance += segment
	return maxf(limit, 8.0)


func _track_dir(offset: float) -> Vector3:
	return -track.get_transform_at(offset).basis.z


func _check_stuck(speed: float, delta: float) -> void:
	if absf(speed) < 2.0:
		_stuck_time += delta
		if _stuck_time > 2.5:
			_stuck_time = 0.0
			car.respawn()
	else:
		_stuck_time = 0.0
