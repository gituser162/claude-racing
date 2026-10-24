extends Skill
## Кур'єр, E — «Черга у відділенні»: усі суперники попереду в радіусі 40 м
## «стають у чергу» — 3 с повзуть на третині швидкості.

@export var radius: float = 40.0
@export var slow_factor: float = 0.35
@export var duration: float = 3.0


func _init() -> void:
	sound = &"queue"


func _activate() -> void:
	Vfx.ring(car, car.body.global_position, Color(1.0, 0.85, 0.2), radius * 0.6, 0.7)
	for other: Car in cars_ahead_within(radius):
		other.apply_slow(slow_factor, duration)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return cars_ahead_within(radius).size() >= 1 and randf() < 0.1
