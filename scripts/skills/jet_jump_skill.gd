extends Skill
## Ракета, E (ультімейт) — «Реактивний стрибок»: високий стрибок із поштовхом уперед.
## Дозволяє перелетіти машини попереду або зрізати шпильку над проваллям.

@export var vertical_speed: float = 13.0
@export var forward_bonus: float = 6.0
## Наскільки можна кермувати в повітрі під час стрибка (0..1).
@export var air_steer: float = 0.8


func _init() -> void:
	sound = &"jump"
	is_ultimate = true


func _can_use() -> bool:
	return car.is_grounded()


func _activate() -> void:
	car.jet_jump(vertical_speed, forward_bonus, air_steer)


func bot_wants_to_use(driver: BotDriver) -> bool:
	# Перестрибнути машину просто попереду або, якщо нікого нема, — на прямій.
	if driver.car_ahead_distance() < 10.0:
		return true
	return driver.is_on_straight() and randf() < 0.004
