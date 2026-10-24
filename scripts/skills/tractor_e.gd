extends Skill
## Трактор, E — «Оранка»: 5 с лишає за собою зорану смугу.
## Хто на неї заїжджає — буксує (сповільнюється).

const MUD_PATH: String = "res://scenes/skills/tractor_mud.tscn"

@export var duration: float = 5.0
@export var drop_interval: float = 0.25

var _time_left: float = 0.0
var _drop_timer: float = 0.0


func _init() -> void:
	sound = &"tractor"
	sound_volume_db = -6.0


func _activate() -> void:
	Vfx.ring(car, car.body.global_position, Color(0.6, 0.4, 0.15), 5.0, 0.5)
	_time_left = duration
	_drop_timer = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if _time_left <= 0.0:
		return
	_time_left -= delta
	_drop_timer -= delta
	if _drop_timer <= 0.0 and car.is_grounded():
		_drop_timer = drop_interval
		spawn_in_world(load(MUD_PATH), transform_behind(car.footprint.y * 0.5 + 1.8))


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return car_behind(40.0) != null and randf() < 0.05
