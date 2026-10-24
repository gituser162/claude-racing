extends Skill
## Кіт-буханка, E — «Коти — рідина»: «протікає» на 30 м уперед по трасі
## і ще 3 с проходить крізь машини.

@export var distance: float = 30.0
@export var ghost_time: float = 3.0


func _init() -> void:
	sound = &"teleport"


func _activate() -> void:
	Vfx.burst(car, car.body.global_position + Vector3.UP * 0.5, Color(1.0, 0.55, 0.2))
	var track := get_track()
	if track:
		var pos := car.body.global_position
		var offset := track.get_offset_of(pos)
		var here := track.get_transform_at(offset)
		var lateral := clampf((pos - here.origin).dot(here.basis.x), -4.0, 4.0)
		car.warp(track.get_transform_at(offset + distance, lateral))
	car.set_ghost(ghost_time)
	Vfx.burst(car, car.body.global_position + Vector3.UP * 0.5, Color(1.0, 0.55, 0.2), 3.0)


func bot_wants_to_use(driver: BotDriver) -> bool:
	return driver.car_ahead_distance() < 15.0 or (driver.is_on_straight() and randf() < 0.004)
