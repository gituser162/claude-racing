extends Skill
## Гусак, E — «Ключ гусей»: зграя летить уздовж траси попереду й розкручує всіх, кого наздожене.

const FLOCK_PATH: String = "res://scripts/skills/goose_flock.gd"


func _init() -> void:
	sound = &"honk"


func _activate() -> void:
	var track := get_track()
	if track == null:
		return
	var flock: Node3D = load(FLOCK_PATH).new()
	flock.track = track
	flock.source_car = car
	flock.start_offset = track.get_offset_of(car.body.global_position) + 4.0
	car.get_parent().add_child(flock)


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return cars_ahead_within(150.0).size() >= 2 or (cars_ahead_within(150.0).size() == 1 and randf() < 0.01)
