extends Skill
## Капібара, E — «Ok I pull up»: телепортується впритул за машину попереду
## (до 300 м уперед по трасі) і 1 с проходить крізь машини, щоб не врізатися.

@export var reach: float = 300.0
@export var gap: float = 6.0


func _init() -> void:
	sound = &"teleport"


func _can_use() -> bool:
	return car_ahead(reach) != null


func _activate() -> void:
	var target := car_ahead(reach)
	var track := get_track()
	if target == null or track == null:
		return
	var offset := track.get_offset_of(target.body.global_position)
	var there := track.get_transform_at(offset)
	var lateral := clampf((target.body.global_position - there.origin).dot(there.basis.x), -4.0, 4.0)
	Vfx.burst(car, car.body.global_position + Vector3.UP * 0.7, Color(0.2, 0.9, 1.0))
	car.warp(track.get_transform_at(offset - gap, lateral))
	Vfx.burst(car, car.body.global_position + Vector3.UP * 0.7, Color(0.2, 0.9, 1.0), 3.0)
	car.set_ghost(1.0)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	var target := car_ahead(reach)
	return target != null and target.body.global_position.distance_to(car.body.global_position) > 40.0
