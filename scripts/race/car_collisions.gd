class_name CarCollisions
extends Node
## Зіткнення між машинами.
## Кожна машина — прямокутник (габарит кузова), повернутий за її курсом.
## Машини, що перетинаються, плавно розштовхуються через швидкість (без «телепорту»).
## Відскок і розворот спрацьовують лише в момент удару, а не щокадру, поки машини труться.
## Важча машина має пріоритет: її «ефективна маса» = маса ^ weight_priority.

signal bumped(a: Car, b: Car, strength: float)

## 1 — звичайна фізика, більше — важка машина домінує сильніше.
@export var weight_priority: float = 3.0
## Пружність удару (0 — «прилипають», 1 — м'ячики).
@export var restitution: float = 0.25
## Мінімальна швидкість, з якою машини розлітаються після удару, м/с — щоб удар відчувався.
@export var min_separation_speed: float = 2.0
## Наскільки швидко розсуваються машини, що заїхали одна в одну (м/с на метр перекриття).
@export var push_stiffness: float = 8.0
@export var max_push_speed: float = 4.0
## Наскільки удар збоку «розвертає» машину.
@export var spin_factor: float = 0.03
## Машини на різній висоті (одна в стрибку) не стикаються.
@export var max_height_difference: float = 1.4

var cars: Array[Car] = []

var _touching: Dictionary = {}   # пари, що торкались минулого кадру


func _ready() -> void:
	# Рахуємо зіткнення раніше за машини, щоб вони одразу врахували нові швидкості.
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	var now: Dictionary = {}
	for i: int in cars.size():
		for j: int in range(i + 1, cars.size()):
			var key := Vector2i(i, j)
			if _resolve(cars[i], cars[j], not _touching.has(key), delta):
				now[key] = true
	_touching = now


## Повертає true, якщо машини торкаються.
func _resolve(a: Car, b: Car, first_contact: bool, delta: float) -> bool:
	if a.is_ghost() or b.is_ghost():
		return false
	var pa := a.ball.global_position
	var pb := b.ball.global_position
	if absf(pa.y - pb.y) > max_height_difference:
		return false
	var offset := Vector2(pb.x - pa.x, pb.z - pa.z)
	var reach := a.footprint.length() * 0.5 + b.footprint.length() * 0.5
	if offset.length_squared() > reach * reach:
		return false

	var hit := _overlap(a, b, offset)
	if hit.is_empty():
		return false
	var normal: Vector2 = hit.normal   # від a до b
	var depth: float = hit.depth
	var n3 := Vector3(normal.x, 0.0, normal.y)

	var ma := pow(a.ball.mass, weight_priority)
	var mb := pow(b.ball.mass, weight_priority)
	var share_a := mb / (ma + mb)   # яку частку поштовху отримує a
	var share_b := ma / (ma + mb)

	var va := a.ball.linear_velocity
	var vb := b.ball.linear_velocity
	var closing := (va - vb).dot(n3)   # > 0 — наближаються

	# М'яке розсування для машин, що вже заїхали одна в одну.
	var push := minf(depth * push_stiffness, max_push_speed)
	var change := 0.0
	if closing > 0.0:
		# Гасимо зближення. При першому дотику — ще й відскок; коли труться боками — без нього.
		var bounce := maxf(closing * restitution, min_separation_speed) if first_contact else 0.0
		change = maxf(closing + bounce, closing + push)
	else:
		# Уже розходяться — лише доштовхуємо до швидкості push, якщо треба.
		change = maxf(push + closing, 0.0)

	if change <= 0.0:
		return true
	var dva := -n3 * change * share_a
	var dvb := n3 * change * share_b
	a.ball.linear_velocity = va + dva
	b.ball.linear_velocity = vb + dvb

	if first_contact and closing > 0.0:
		a.nudge_heading(-dva.dot(a.get_forward().cross(Vector3.UP)) * spin_factor)
		b.nudge_heading(-dvb.dot(b.get_forward().cross(Vector3.UP)) * spin_factor)
		bumped.emit(a, b, change)
	return true


## Перевірка перетину двох повернутих прямокутників (теорема про розділяючу вісь).
## Повертає {normal, depth} або порожній словник, якщо не перетинаються.
func _overlap(a: Car, b: Car, offset: Vector2) -> Dictionary:
	var fa := _flat(a.get_forward())
	var fb := _flat(b.get_forward())
	var axes: Array[Vector2] = [fa, fa.orthogonal(), fb, fb.orthogonal()]
	var best_depth := INF
	var best_axis := Vector2.ZERO
	for axis: Vector2 in axes:
		var ra := _radius_on(a, fa, axis)
		var rb := _radius_on(b, fb, axis)
		var distance := offset.dot(axis)
		var depth := ra + rb - absf(distance)
		if depth <= 0.0:
			return {}
		if depth < best_depth:
			best_depth = depth
			best_axis = axis if distance >= 0.0 else -axis
	return {"normal": best_axis, "depth": best_depth}


func _radius_on(car: Car, forward: Vector2, axis: Vector2) -> float:
	var half := car.footprint * 0.5   # x — ширина, y — довжина
	return half.x * absf(forward.orthogonal().dot(axis)) + half.y * absf(forward.dot(axis))


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z).normalized()
