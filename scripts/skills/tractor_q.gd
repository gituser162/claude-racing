extends Skill
## Трактор, Q — «Буксир»: чіпляє тросом найближчу машину (до 18 м)
## і 3 с тягне її за собою (вона ще й сповільнена).

@export var reach: float = 18.0
@export var duration: float = 3.0
@export var rope_length: float = 6.0

var _target: Car
var _time_left: float = 0.0
var _rope: MeshInstance3D


func _init() -> void:
	sound = &"tractor"
	sound_volume_db = -6.0
	cooldown = 9.0


func _can_use() -> bool:
	return _nearest() != null


func _activate() -> void:
	_target = _nearest()
	_time_left = duration
	if _rope == null:
		_rope = MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.08, 1.0)
		_rope.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://resources/shaders/psx.gdshader")
		mat.set_shader_parameter(&"albedo", Color(0.6, 0.5, 0.2))
		mat.set_shader_parameter(&"emission", Color(1.0, 0.8, 0.3))
		mat.set_shader_parameter(&"emission_energy", 1.0)
		_rope.material_override = mat
		_rope.top_level = true
		add_child(_rope)
	_rope.visible = true


func _physics_process(delta: float) -> void:
	super(delta)
	if _time_left <= 0.0 or _target == null:
		return
	_time_left -= delta
	var from := car.body.global_position + Vector3.UP * 0.8
	var to := _target.body.global_position + Vector3.UP * 0.8
	var gap := to - from
	if gap.length() > reach * 2.0:
		# Ціль респавнилась чи телепортувалась — трос рветься.
		_time_left = 0.0
		_rope.visible = false
		return
	if gap.length() > rope_length:
		# Тягнемо ціль до себе, наче тросом (не більше 1 м/с за кадр).
		var pull := -gap.normalized() * minf((gap.length() - rope_length) * 4.0 * delta, 1.0)
		pull.y = 0.0
		_target.push(pull)
	_target.apply_slow(0.75, 0.2)
	if gap.length() > 0.1:
		_rope.global_transform = Transform3D(Basis.looking_at(gap.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, gap.length())), (from + to) * 0.5)
	if _time_left <= 0.0 or _target.is_protected():
		_time_left = 0.0
		_rope.visible = false


func _nearest() -> Car:
	var best: Car = null
	var best_d := reach
	for other: Car in cars_within(reach):
		var d := other.body.global_position.distance_to(car.body.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best


func bot_wants_to_use(_driver: BotDriver) -> bool:
	return randf() < 0.05
