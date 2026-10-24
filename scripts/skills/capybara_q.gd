extends Skill
## Капібара, Q — «Спокій»: 3 с ніщо не може її потурбувати (захист від скілів).

@export var duration: float = 3.0


func _init() -> void:
	sound = &"shield"
	cooldown = 9.0


func _activate() -> void:
	car.set_protected(duration)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return cars_within(10.0).size() > 0 and randf() < 0.05
