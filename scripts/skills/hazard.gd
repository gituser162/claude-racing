class_name Hazard
extends Area3D
## Перешкода чи снаряд, які залишає скіл (коробка, калюжа, міна, ракета...).
## Сцена: корінь Area3D з цим скриптом + CollisionShape3D + будь-яка модель.
## Коли в зону заїжджає машина — на неї діє effect. Свою машину (source_car)
## перешкода не чіпає перші owner_immunity секунд.

enum Effect { SLOW, SPIN, PUSH_UP }

@export var effect: Effect = Effect.SLOW
## SLOW: множник швидкості й тривалість. SPIN: тривалість розкрутки. PUSH_UP: сила підкидання.
@export var strength: float = 0.5
@export var duration: float = 2.0
## Зникає після першого спрацювання.
@export var single_use: bool = true
## Скільки живе, с (0 — назавжди).
@export var lifetime: float = 12.0
@export var owner_immunity: float = 1.0
## Рух уперед (для снарядів), м/с.
@export var speed: float = 0.0

var source_car: Car
var _age: float = 0.0


func _ready() -> void:
	collision_layer = 8   # шар «skills»
	collision_mask = 2    # бачить машини
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if speed != 0.0:
		global_position += -global_basis.z * speed * delta
	if lifetime > 0.0 and _age > lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var car := body.get_parent() as Car
	if car == null or (car == source_car and _age < owner_immunity):
		return
	var hit := false
	match effect:
		Effect.SLOW:
			hit = car.apply_slow(strength, duration)
		Effect.SPIN:
			hit = car.spin_out(duration)
		Effect.PUSH_UP:
			hit = car.push(Vector3.UP * strength)
	if hit or car.is_protected():
		Audio.play_at(&"hit", global_position)
		Vfx.burst(self, global_position + Vector3.UP * 0.6, Color(1.0, 0.4, 0.2), 1.8, 0.35)
		_on_hit(car)
		if single_use:
			queue_free()


## Перевизначте, щоб додати щось при влучанні (звук, ефект).
func _on_hit(_car: Car) -> void:
	pass
