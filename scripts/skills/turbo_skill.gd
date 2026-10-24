extends Skill
## Ракета, Q — «Турбо»: коротке прискорення понад максимальну швидкість.

@export var speed_multiplier: float = 1.5
@export var duration: float = 2.0
## Миттєвий поштовх уперед на старті турбо, м/с.
@export var kick: float = 3.0


func _init() -> void:
	sound = &"boost"
	cooldown = 8.0


func _activate() -> void:
	car.add_boost(speed_multiplier, duration, kick)


func bot_wants_to_use(driver: BotDriver) -> bool:
	# Бот вмикає турбо на прямій, не завжди одразу — щоб боти не робили це синхронно.
	return driver.is_on_straight() and car.get_speed() > 12.0 and randf() < 0.03
