extends Skill
## Офісний планктон, E — «Дедлайн»: 4 с шаленої швидкості, але кермо «ватне».

@export var duration: float = 4.0


func _init() -> void:
	sound = &"boost"


func _activate() -> void:
	Vfx.ring(car, car.body.global_position, Color(1.0, 0.2, 0.75), 5.0, 0.4)
	car.add_boost(1.75, duration, 4.0)
	car.set_steer_multiplier(0.45, duration)


func bot_wants_to_use(driver: BotDriver) -> bool:
	return driver.is_on_straight() and randf() < 0.01
