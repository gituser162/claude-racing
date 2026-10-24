extends Skill
## Гусак, Q — «Щипок»: щипає машину попереду (до 15 м) — та розкручується.

@export var reach: float = 15.0


func _init() -> void:
	sound = &"honk"
	cooldown = 9.0


func _can_use() -> bool:
	return car_ahead(reach) != null


func _activate() -> void:
	var target := car_ahead(reach)
	if target:
		target.spin_out(0.9)
		Vfx.burst(target, target.body.global_position + Vector3.UP * 0.8, Color(1.0, 1.0, 0.9), 1.6)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return randf() < 0.1
