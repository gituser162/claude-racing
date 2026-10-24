extends Skill
## Маршрутка, E — «Ще один влізе»: набирає «пасажирів» — 6 с утричі важча,
## трохи швидша й не піддається чужим скілам. Таранить усіх.

@export var duration: float = 6.0


func _init() -> void:
	sound = &"horn"


func _activate() -> void:
	Vfx.ring(car, car.body.global_position, Color(1.0, 0.75, 0.1), 6.0, 0.6)
	car.set_mass_multiplier(3.0, duration)
	car.add_boost(1.15, duration, 2.0)
	car.set_protected(duration)


func bot_wants_to_use(driver: BotDriver) -> bool:
	return driver.car_ahead_distance() < 20.0 or randf() < 0.004
