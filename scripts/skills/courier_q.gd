extends Skill
## Кур'єр, Q — «Посилка»: скидає коробку на трасу позаду. Хто врізається — гальмує.

const PARCEL_PATH: String = "res://scenes/skills/courier_parcel.tscn"


func _init() -> void:
	sound = &"parcel"
	cooldown = 7.0


func _activate() -> void:
	spawn_in_world(load(PARCEL_PATH), transform_behind(car.footprint.y * 0.5 + 1.5))


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return car_behind(30.0) != null and randf() < 0.05
