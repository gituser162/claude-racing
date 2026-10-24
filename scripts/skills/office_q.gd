extends Skill
## Офісний планктон, Q — «Кава»: коротке турбо на 2 с.

func _init() -> void:
	sound = &"coffee"
	cooldown = 17.0


func _activate() -> void:
	car.add_boost(1.35, 2.0, 2.5)


func bot_wants_to_use(driver: BotDriver) -> bool:
	return driver.is_on_straight() and car.get_speed() > 12.0 and randf() < 0.03
