extends Skill
## Маршрутка, Q — «Передайте за проїзд»: «тягне» машину попереду назад
## (сповільнює її на 2 с), а себе — вперед.

@export var reach: float = 30.0


func _init() -> void:
	sound = &"horn"
	cooldown = 8.0


func _can_use() -> bool:
	return car_ahead(reach) != null


func _activate() -> void:
	var target := car_ahead(reach)
	if target:
		target.apply_slow(0.6, 2.0)
		Vfx.burst(target, target.body.global_position + Vector3.UP * 0.8, Color(1.0, 0.6, 0.1), 1.8)
	car.add_boost(1.25, 2.0, 3.0)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return randf() < 0.05
