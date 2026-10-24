class_name ChaseCamera
extends Camera3D
## Камера від третьої особи, що плавно їде за машиною.
## - Поле зору розширюється на швидкості й ще більше під турбо.
## - Тремтить від ударів, влучань і жорстких приземлень (add_shake).
## - Не заходить під дорогу й крізь стіни: якщо між машиною й камерою щось є, підсувається ближче.

@export var target: Car
@export var distance: float = 6.5
@export var height: float = 2.6
@export var look_height: float = 1.0
@export var look_ahead: float = 3.0
@export var follow_speed: float = 10.0
@export var fov_min: float = 70.0
@export var fov_max: float = 86.0
@export var boost_fov: float = 8.0
## Максимальний зсув кадру при найсильнішому трусінні.
@export var shake_max_offset: float = 0.35
@export var shake_decay: float = 2.2

var _trauma: float = 0.0
var _noise_time: float = 0.0


func _ready() -> void:
	if target:
		target.respawned.connect(snap)
		target.jolted.connect(add_shake)
		snap()


## Додає «струс» камери (0..1). Сила росте квадратично, тож дрібні удари ледь помітні.
func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Підлаштовує відстань під розмір гонщика: великий фургон не має закривати дорогу.
func _fit_to_target() -> void:
	var length := target.footprint.y
	distance = 4.0 + length * 0.95
	height = 1.7 + length * 0.3
	look_ahead = 2.0 + length * 0.4


## Миттєво ставить камеру на місце (після респауну чи на старті).
func snap() -> void:
	_fit_to_target()
	global_position = _desired_position()
	_look()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_desired_position(), weight)
	_look()
	var speed_ratio := clampf(absf(target.get_speed()) / target.max_speed, 0.0, 1.0)
	var wanted_fov := lerpf(fov_min, fov_max, speed_ratio) + (boost_fov if target.is_boosting() else 0.0)
	fov = lerpf(fov, wanted_fov, weight)
	_apply_shake(delta)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	_noise_time += delta * 40.0
	var power := _trauma * _trauma * shake_max_offset
	h_offset = sin(_noise_time * 1.3) * cos(_noise_time * 0.7) * power
	v_offset = sin(_noise_time * 1.1 + 2.0) * power


func _desired_position() -> Vector3:
	var pivot := target.body.global_position + Vector3.UP * 1.2
	var wanted := target.body.global_position - target.get_forward() * distance + Vector3.UP * height
	# Якщо між машиною й камерою дорога чи стіна — ставимо камеру перед перешкодою.
	var query := PhysicsRayQueryParameters3D.create(pivot, wanted, 1, [target.ball.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position + hit.normal * 0.4
	return wanted


func _look() -> void:
	var point := target.body.global_position + Vector3.UP * look_height + target.get_forward() * look_ahead
	look_at(point, Vector3.UP)
