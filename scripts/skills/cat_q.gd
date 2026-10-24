extends Skill
## Кіт-буханка, Q — «Шшш!»: шипить і відштовхує всіх у радіусі 7 м.

@export var radius: float = 7.0
@export var force: float = 9.0


func _init() -> void:
	sound = &"hiss"
	cooldown = 8.0


func _activate() -> void:
	var center := car.body.global_position
	Vfx.ring(car, center, Color(1.0, 0.55, 0.2), radius)
	for other: Car in cars_within(radius):
		var away := other.body.global_position - center
		away.y = 0.0
		if away.length() < 0.1:
			away = car.get_forward().cross(Vector3.UP)
		other.push(away.normalized() * force + Vector3.UP * 2.0)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return cars_within(radius - 1.0).size() > 0 and randf() < 0.2
