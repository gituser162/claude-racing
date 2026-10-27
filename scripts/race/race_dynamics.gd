class_name RaceDynamics
extends RefCounted
## Динаміка гонки (прихована від гравця): єдина система множників максимальної швидкості,
## що залежать від положення машин ВІДНОСНО ГРАВЦЯ. Мета — гонка динамічна й хаотична,
## а гравець завжди в центрі подій.
##  1. «Зграя навколо гравця»: боти, що сильно відстали від гравця, швидшають; ті, що
##     сильно відірвались уперед, сповільнюються — машини весь час збираються біля гравця.
##  2. «Хаос поруч»: боти в радіусі CHAOS_RADIUS від гравця отримують випадкові короткі
##     ривки й просідання швидкості — постійні обгони й боротьба поруч із гравцем.
##  3. «Наздоганяння гравця»: якщо лідер далеко попереду гравця, гравець трохи швидшає.
##     Коли гравець лідирує, сам він бафу не має — його наздоганяють боти (пункт 1).
## Усі ефекти змінюються плавно й перемножуються, підсумок обмежено [MIN_MULTIPLIER, MAX_MULTIPLIER].
## Ставить Car.race_speed_multiplier (його враховують і фізика машини, і боти).

## Бот позаду гравця: до +25% (повна сила, коли відстав на PULL_BEHIND_FULL метрів).
const PULL_BEHIND_MAX: float = 0.25
const PULL_BEHIND_START: float = 10.0
const PULL_BEHIND_FULL: float = 80.0
## Бот попереду гравця: до −18% (повна сила на відриві PULL_AHEAD_FULL метрів).
const PULL_AHEAD_MAX: float = 0.18
const PULL_AHEAD_START: float = 20.0
const PULL_AHEAD_FULL: float = 120.0
## Хаос біля гравця: випадковий ривок/просідання бота в межах [CHAOS_MIN, CHAOS_MAX],
## новий кожні CHAOS_PERIOD_MIN..CHAOS_PERIOD_MAX секунд.
const CHAOS_RADIUS: float = 45.0
const CHAOS_MIN: float = -0.06
const CHAOS_MAX: float = 0.08
const CHAOS_PERIOD_MIN: float = 1.5
const CHAOS_PERIOD_MAX: float = 3.5
## Гравець позаду лідера: до +10% (повна сила, коли лідер попереду на PLAYER_CATCHUP_FULL метрів).
const PLAYER_CATCHUP_MAX: float = 0.10
const PLAYER_CATCHUP_START: float = 30.0
const PLAYER_CATCHUP_FULL: float = 150.0
## Межі підсумкового множника й швидкість, з якою він плавно наближається до цілі (1/с).
const MIN_MULTIPLIER: float = 0.8
const MAX_MULTIPLIER: float = 1.3
const SMOOTHING: float = 1.5
## Як часто перераховувати цілі (с).
const INTERVAL: float = 0.25

var _timer: float = 0.0
var _targets: Dictionary = {}    # Car -> float
var _chaos: Dictionary = {}      # Car -> float (поточний випадковий ривок)
var _chaos_left: Dictionary = {} # Car -> float (секунд до нового ривка)
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## Викликати щокадру фізики під час гонки.
## progress(car) -> пройдена відстань від старту в метрах (з урахуванням кіл),
## finished(car) -> чи машина вже фінішувала.
func update(delta: float, cars: Array[Car], player: Car, progress: Callable, finished: Callable) -> void:
	_tick_chaos(delta, cars)
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		_recompute(cars, player, progress, finished)
	for car: Car in cars:
		var target: float = _targets.get(car, 1.0)
		car.race_speed_multiplier = lerpf(car.race_speed_multiplier, target, 1.0 - exp(-SMOOTHING * delta))


## Знімає всі ефекти (наприклад, після фінішу гравця).
func reset(cars: Array[Car]) -> void:
	_targets.clear()
	for car: Car in cars:
		car.race_speed_multiplier = 1.0


func _recompute(cars: Array[Car], player: Car, progress: Callable, finished: Callable) -> void:
	var player_done: bool = finished.call(player)
	var player_progress: float = progress.call(player)
	var leader_progress := player_progress
	for car: Car in cars:
		if not finished.call(car):
			leader_progress = maxf(leader_progress, progress.call(car))
	for car: Car in cars:
		var multiplier := 1.0
		if player_done or finished.call(car):
			_targets[car] = 1.0
			continue
		if car == player:
			var behind_leader := leader_progress - player_progress
			multiplier += PLAYER_CATCHUP_MAX * smoothstep(PLAYER_CATCHUP_START, PLAYER_CATCHUP_FULL, behind_leader)
		else:
			# Додатне — бот попереду гравця, від'ємне — позаду.
			var gap: float = progress.call(car) - player_progress
			if gap < 0.0:
				multiplier += PULL_BEHIND_MAX * smoothstep(PULL_BEHIND_START, PULL_BEHIND_FULL, -gap)
			else:
				multiplier -= PULL_AHEAD_MAX * smoothstep(PULL_AHEAD_START, PULL_AHEAD_FULL, gap)
			if absf(gap) < CHAOS_RADIUS:
				multiplier += _chaos.get(car, 0.0)
		_targets[car] = clampf(multiplier, MIN_MULTIPLIER, MAX_MULTIPLIER)


func _tick_chaos(delta: float, cars: Array[Car]) -> void:
	for car: Car in cars:
		var left: float = _chaos_left.get(car, 0.0) - delta
		if left <= 0.0:
			_chaos[car] = _rng.randf_range(CHAOS_MIN, CHAOS_MAX)
			left = _rng.randf_range(CHAOS_PERIOD_MIN, CHAOS_PERIOD_MAX)
		_chaos_left[car] = left
