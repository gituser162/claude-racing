class_name Car
extends Node3D
## Аркадна машина. Фізика — куля (RigidBody3D), яка ковзає по землі;
## видима модель (Body) їде за кулею і повертається за курсом.
## Модель береться з гонщика (RacerData.model_scene) — див. docs/ADDING_RACERS.md.
## Керування подається через throttle_input / steer_input:
## гравець читає клавіатуру тут, боти задають ці значення самі.
##
## Ефекти для скілів (усі безпечні до виклику будь-коли):
##   add_boost, jet_jump, apply_slow, spin_out, push, set_protected, set_ghost, set_mass_multiplier,
##   set_steer_multiplier, warp.
## Ефекти, що шкодять (apply_slow, spin_out, push), не діють на машину під захистом (set_protected).

signal respawned
## Машину смикнуло (удар, влучання, жорстке приземлення); strength 0..1 — для тремтіння камери.
signal jolted(strength: float)

## Значення характеристик за зірками 1..3 (індекс 0 не використовується).
const STAT_MAX_SPEED: Array[float] = [0.0, 29.0, 30.5, 32.0]   # м/с (≈ 104 / 110 / 115 км/год)
const STAT_ACCEL: Array[float] = [0.0, 12.0, 14.5, 17.0]       # м/с²
const STAT_TURN: Array[float] = [0.0, 1.9, 2.3, 2.7]           # рад/с
const STAT_MASS: Array[float] = [0.0, 100.0, 140.0, 180.0]     # кг (впливає на зіткнення)

const BALL_RADIUS: float = 0.5
const YAW_KICK_TIME: float = 0.25
const PSX_SHADER: Shader = preload("res://resources/shaders/psx.gdshader")
const DEFAULT_MODEL: PackedScene = preload("res://scenes/racers/rocket/model.tscn")

@export var racer: RacerData
@export var controlled_by_player: bool = true
## Габарит кузова для зіткнень між машинами: ширина × довжина, м. Береться з гонщика.
var footprint: Vector2 = Vector2(1.7, 2.9)

@export_group("Їзда")
@export var reverse_speed: float = 9.0
@export var brake_decel: float = 30.0
@export var coast_decel: float = 5.0
## Наскільки сильно гаситься бокове ковзання (більше — машина «на рейках»).
@export var grip: float = 14.0
## Множник швидкості повороту на максимальній швидкості.
@export var high_speed_turn_factor: float = 0.65
@export var air_steer_factor: float = 0.3
@export var fall_limit_y: float = -12.0

@export_group("Поза трасою")
## Частка максимальної швидкості на траві (поверхні з групи «offroad»).
@export var offroad_speed_factor: float = 0.55
## Як швидко гальмує, якщо заїхав на траву швидше за ліміт.
@export var offroad_decel: float = 14.0

@export_group("Занос")
## З якої частки макс. швидкості й якого відхилення керма машину починає заносити.
@export var drift_speed_start: float = 0.72
@export var drift_steer_start: float = 0.55
## Бокове зчеплення в повному заносі (звичайне — grip). Менше — довше ковзає вбік.
@export var drift_grip: float = 3.5
## У заносі машина повертається трохи сильніше — «хвіст» виносить назовні.
@export var drift_turn_boost: float = 1.25
## Втрата швидкості від бокового ковзання.
@export var drift_scrub: float = 0.35

@export_group("Вигляд")
@export var max_wheel_angle: float = 0.45
@export var max_body_roll: float = 0.09

var throttle_input: float = 0.0
var steer_input: float = 0.0

var max_speed: float
## Прихований баф «наздоганяння» (множник макс. швидкості). Ставить сцена гонки
## для тих, хто відстає (див. main.gd), на HUD не показується.
var catchup_multiplier: float = 1.0
## Прихований множник розгону (ставить сцена гонки: боти розганяються швидше, коли гравець лідирує).
var accel_multiplier: float = 1.0
var acceleration: float
var turn_speed: float

var _heading: float = 0.0
var _grounded: bool = false
var _offroad: bool = false
var _yaw_kick: float = 0.0   # рад/с, затухає
var _boost_left: float = 0.0
var _boost_multiplier: float = 1.0
var _jumping: bool = false
var _jump_air_steer: float = 0.0
var _jump_grace: float = 0.0   # перші миті стрибка ще «бачимо» землю — не вважаємо це приземленням
var _slow_left: float = 0.0
var _slow_factor: float = 1.0
var _spin_left: float = 0.0
var _spin_rate: float = 0.0
## Курс, з яким машина вийде з розкрутки (той самий, що був до неї).
var _spin_end_heading: float = 0.0
var _protect_left: float = 0.0
var _ghost_left: float = 0.0
var _mass_left: float = 0.0
var _steer_left: float = 0.0
var _steer_multiplier: float = 1.0
var _base_mass: float = 100.0
var _model_instance: Node3D
var _front_wheels: Array[Node3D] = []
var _wheel_spins: Array[Node3D] = []
var _paint_meshes: Array[MeshInstance3D] = []

## Скіли машини (Q і E). Створюються автоматично.
var skills: SkillController
var _trail: MeshInstance3D
var _engine: AudioStreamPlayer3D
## Сила заносу 0..1 і поточна бокова швидкість (для диму й звуку шин).
var _drift: float = 0.0
var _lateral_speed: float = 0.0
var _skid: AudioStreamPlayer3D
var _smoke: Array[CPUParticles3D] = []
var _is_player_car: bool = false
var _air_time: float = 0.0
var _ground_normal: Vector3 = Vector3.UP
var _smoothed_up: Vector3 = Vector3.UP
var _spawn: Transform3D

@onready var ball: RigidBody3D = $Ball
@onready var body: Node3D = $Body
@onready var _ground_ray: RayCast3D = $Ball/GroundRay
@onready var _model: Node3D = $Body/Model
@onready var _exhaust: Node3D = $Body/Model/Exhaust
@onready var _jet_flame: Node3D = $Body/Model/JetFlame
@onready var _underglow: Node3D = $Body/Model/Underglow
@onready var _shield: Node3D = $Body/Shield
var _slow_ring: MeshInstance3D


func _ready() -> void:
	body.top_level = true
	skills = SkillController.new()
	skills.name = "Skills"
	skills.car = self
	add_child(skills)
	_is_player_car = controlled_by_player
	_engine = AudioStreamPlayer3D.new()
	_engine.name = "Engine"
	_engine.stream = Audio.get_sound(&"engine_loop")
	_engine.bus = &"SFX"
	_engine.unit_size = 6.0
	_engine.max_distance = 90.0
	_engine.volume_db = -9.0 if _is_player_car else -18.0
	body.add_child(_engine)
	_engine.play()
	_skid = AudioStreamPlayer3D.new()
	_skid.name = "Skid"
	_skid.stream = Audio.get_sound(&"skid_loop")
	_skid.bus = &"SFX"
	_skid.unit_size = 6.0
	_skid.max_distance = 70.0
	body.add_child(_skid)
	_slow_ring = _make_slow_ring()
	body.add_child(_slow_ring)
	_trail = load("res://scripts/car/light_trail.gd").new()
	_trail.name = "LightTrail"
	_trail.car = self
	add_child(_trail)
	_spawn = global_transform
	_heading = global_rotation.y
	if racer == null:
		racer = Game.selected_racer
	apply_racer(racer)
	_sync_body(1.0)


## Застосовує характеристики, модель, колір і скіли гонщика.
func apply_racer(data: RacerData) -> void:
	racer = data
	max_speed = STAT_MAX_SPEED[data.speed] * data.top_speed_multiplier
	acceleration = STAT_ACCEL[data.acceleration]
	turn_speed = STAT_TURN[data.handling]
	_base_mass = STAT_MASS[data.weight]
	ball.mass = _base_mass
	footprint = data.footprint
	_load_model(data.model_scene if data.model_scene else DEFAULT_MODEL)
	var paint := ShaderMaterial.new()
	paint.shader = PSX_SHADER
	# Приглушуємо колір: у PS1-стилі фарба не «мультяшно» яскрава.
	paint.set_shader_parameter(&"albedo", data.car_color.darkened(0.25))
	for mesh: MeshInstance3D in _paint_meshes:
		mesh.material_override = paint
	skills.set_racer(data)


## Ставить модель гонщика в Body/Model і знаходить у ній вузли за групами:
## «paint» — фарбуються в колір гонщика, «steer» — повертаються з кермом, «spin» — крутяться (колеса).
func _load_model(scene: PackedScene) -> void:
	if _model_instance:
		_model.remove_child(_model_instance)
		_model_instance.queue_free()
	_model_instance = scene.instantiate()
	_model.add_child(_model_instance)
	_front_wheels.clear()
	_wheel_spins.clear()
	_paint_meshes.clear()
	for node: Node in _model_instance.find_children("*", "", true, false):
		if node.is_in_group(&"paint") and node is MeshInstance3D:
			_paint_meshes.append(node)
		if node.is_in_group(&"steer") and node is Node3D:
			_front_wheels.append(node)
		if node.is_in_group(&"spin") and node is Node3D:
			_wheel_spins.append(node)
	# Загальні ефекти підганяємо під розмір моделі.
	_exhaust.position.z = footprint.y * 0.5 + 0.3
	_underglow.scale = Vector3(footprint.x / 1.7, 1.0, footprint.y / 2.9)
	_jet_flame.scale = _underglow.scale
	_shield.scale = Vector3(footprint.x * 0.75, 1.0, footprint.y * 0.62)
	_build_headlights()
	_build_drift_fx()


## Промені фар: два світлові конуси попереду машини (видно в тумані й дощі).
func _build_headlights() -> void:
	var old := body.get_node_or_null(^"Headlights")
	if old:
		old.free()
	var holder := Node3D.new()
	holder.name = "Headlights"
	body.add_child(holder)
	var length := 10.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 2.0
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://resources/shaders/light_beam.gdshader")
	# Вісь конуса: від фари вперед і трохи вниз (верх циліндра — біля фари).
	var tilt := deg_to_rad(84.0)
	var top_dir := Vector3(0.0, cos(tilt), sin(tilt))
	for side: float in [-1.0, 1.0]:
		var beam := MeshInstance3D.new()
		beam.mesh = mesh
		beam.material_override = mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var source := Vector3(side * footprint.x * 0.32, 0.55, -footprint.y * 0.5)
		beam.position = source - top_dir * length * 0.5
		beam.rotation.x = tilt
		holder.add_child(beam)


## Дим із-під задніх коліс (вмикається в заносі, див. _animate).
func _build_drift_fx() -> void:
	for old: CPUParticles3D in _smoke:
		old.queue_free()
	_smoke.clear()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.35
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.72, 0.82, 0.45))
	fade.set_color(1, Color(0.6, 0.55, 0.7, 0.0))
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 2.2))
	for side: float in [-1.0, 1.0]:
		var smoke := CPUParticles3D.new()
		smoke.mesh = mesh
		smoke.amount = 28
		smoke.lifetime = 0.8
		smoke.emitting = false
		smoke.local_coords = false
		smoke.direction = Vector3(0.0, 1.0, 0.6)
		smoke.spread = 50.0
		smoke.initial_velocity_min = 0.6
		smoke.initial_velocity_max = 1.6
		smoke.gravity = Vector3(0.0, 0.8, 0.0)
		smoke.angular_velocity_min = -90.0
		smoke.angular_velocity_max = 90.0
		smoke.scale_amount_curve = grow
		smoke.color_ramp = fade
		smoke.position = Vector3(side * footprint.x * 0.4, 0.2, footprint.y * 0.42)
		body.add_child(smoke)
		_smoke.append(smoke)


## Справжнє світло фар (SpotLight) — лише для машини гравця, щоб не навантажувати рендер.
func enable_headlight_light() -> void:
	var light := SpotLight3D.new()
	light.name = "HeadlightLight"
	light.light_color = Color(1.0, 0.92, 0.78)
	light.light_energy = 4.0
	light.spot_range = 26.0
	light.spot_angle = 32.0
	light.spot_attenuation = 0.8
	light.position = Vector3(0.0, 1.2, -footprint.y * 0.5)
	light.rotation.x = deg_to_rad(-12.0)
	body.add_child(light)
	# М'яке заповнювальне світло ззаду-зверху: інакше з камери видно лише темний силует.
	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.8, 0.75, 1.0)
	fill.light_energy = 1.4
	fill.omni_range = 9.0
	fill.omni_attenuation = 1.2
	fill.position = Vector3(0.0, 3.0, footprint.y * 0.5 + 3.0)
	body.add_child(fill)


## Напрямок «вперед» за курсом машини (горизонтальний).
func get_forward() -> Vector3:
	return Vector3(-sin(_heading), 0.0, -cos(_heading))


## Швидкість уздовж напрямку руху, м/с (від'ємна — задній хід).
func get_speed() -> float:
	return ball.linear_velocity.dot(get_forward())


func is_grounded() -> bool:
	return _grounded


func is_offroad() -> bool:
	return _offroad


## Миттєво ставить машину в точку (старт гонки) і запам'ятовує її як точку респауну.
func teleport(point: Transform3D) -> void:
	set_respawn_point(point)
	respawn(true)


## Тимчасове прискорення: максимальна швидкість × multiplier на duration секунд
## плюс миттєвий поштовх уперед на kick м/с.
func add_boost(multiplier: float, duration: float, kick: float = 0.0) -> void:
	_boost_multiplier = multiplier
	_boost_left = duration
	if kick != 0.0:
		ball.linear_velocity += get_forward() * kick


func is_boosting() -> bool:
	return _boost_left > 0.0


## Реактивний стрибок: вертикальна швидкість + поштовх уперед. У повітрі краще кермується.
func jet_jump(vertical_speed: float, forward_bonus: float, air_steer: float) -> void:
	var v := ball.linear_velocity
	v.y = maxf(v.y, 0.0) + vertical_speed
	v += get_forward() * forward_bonus
	ball.linear_velocity = v
	_jumping = true
	_jump_air_steer = air_steer
	_jump_grace = 0.15


func is_jumping() -> bool:
	return _jumping


## Сповільнення: максимальна швидкість × factor на duration с. Не діє під захистом.
func apply_slow(factor: float, duration: float) -> bool:
	if is_protected():
		return false
	_slow_factor = minf(factor, _slow_factor) if _slow_left > 0.0 else factor
	_slow_left = maxf(_slow_left, duration)
	if factor < 0.9:
		Audio.play_at(&"slow", body.global_position, -4.0)
		jolted.emit(0.3)
	return true


func is_slowed() -> bool:
	return _slow_left > 0.0


## Розкрутка: машина втрачає керування й робить рівно один оберт за duration с,
## швидкість падає вдвічі. Після оберту машина дивиться туди ж, куди їхала, а не задом.
func spin_out(duration: float = 0.9) -> bool:
	if is_protected() or is_spinning():
		return false
	var direction := 1.0 if randf() < 0.5 else -1.0
	_spin_left = duration
	_spin_rate = TAU / duration * direction
	_spin_end_heading = _heading + TAU * direction
	ball.linear_velocity *= Vector3(0.5, 1.0, 0.5)
	Audio.play_at(&"spin", body.global_position)
	jolted.emit(0.6)
	return true


func is_spinning() -> bool:
	return _spin_left > 0.0


## Поштовх: миттєво додає швидкість (м/с у світових координатах). Не діє під захистом.
func push(velocity_change: Vector3) -> bool:
	if is_protected():
		return false
	ball.linear_velocity += velocity_change
	if velocity_change.length() > 3.0:
		jolted.emit(clampf(velocity_change.length() / 15.0, 0.0, 0.6))
	return true


## Захист: duration с не діють сповільнення, розкрутка й поштовхи від скілів.
func set_protected(duration: float) -> void:
	_protect_left = maxf(_protect_left, duration)


func is_protected() -> bool:
	return _protect_left > 0.0


## Привид: duration с машина проходить крізь інші машини (немає зіткнень).
func set_ghost(duration: float) -> void:
	_ghost_left = maxf(_ghost_left, duration)


func is_ghost() -> bool:
	return _ghost_left > 0.0


## Тимчасово змінює масу (наприклад, «надважка» машина таранить усіх).
func set_mass_multiplier(multiplier: float, duration: float) -> void:
	ball.mass = _base_mass * multiplier
	_mass_left = duration


## Тимчасово змінює чутливість керма (менше 1 — «ватне» кермо).
func set_steer_multiplier(multiplier: float, duration: float) -> void:
	_steer_multiplier = multiplier
	_steer_left = duration


## Переносить машину в точку траси, зберігаючи швидкість (на відміну від teleport,
## не змінює точку респауну й не зупиняє машину).
func warp(point: Transform3D) -> void:
	var speed := maxf(get_speed(), 0.0)
	_heading = point.basis.get_euler().y
	ball.global_position = point.origin + Vector3.UP * BALL_RADIUS
	ball.linear_velocity = get_forward() * speed
	_sync_body(1.0)
	body.reset_physics_interpolation()
	ball.reset_physics_interpolation()
	_trail.clear()


## Фіолетове кільце над машиною, поки вона сповільнена.
func _make_slow_ring() -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.55
	mesh.outer_radius = 0.7
	mesh.rings = 12
	mesh.ring_segments = 4
	ring.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://resources/shaders/psx_glow.gdshader")
	mat.set_shader_parameter(&"color", Color(0.7, 0.3, 1.0))
	mat.set_shader_parameter(&"intensity", 1.6)
	mat.set_shader_parameter(&"rim", false)
	ring.material_override = mat
	ring.position = Vector3.UP * 2.2
	ring.visible = false
	return ring


## Плавно розвертає машину на кут (рад, + ліворуч) — використовується при ударах.
## Поворот розтягується на ~0.3 с, щоб машина й камера не смикались.
func nudge_heading(angle: float) -> void:
	_yaw_kick += clampf(angle, -0.35, 0.35) / YAW_KICK_TIME


func set_respawn_point(point: Transform3D) -> void:
	_spawn = point


func respawn(silent: bool = false) -> void:
	if not silent:
		Audio.play_at(&"respawn", _spawn.origin)
		# Коротка невразливість до зіткнень після респауну, щоб не врізатись одразу.
		set_ghost(1.2)
		Vfx.burst(self, _spawn.origin + Vector3.UP * 0.8, Color(0.2, 0.9, 1.0), 2.5)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	_yaw_kick = 0.0
	_boost_left = 0.0
	_jumping = false
	_slow_left = 0.0
	_spin_left = 0.0
	_drift = 0.0
	_lateral_speed = 0.0
	ball.global_position = _spawn.origin + Vector3.UP * BALL_RADIUS
	_heading = _spawn.basis.get_euler().y
	_smoothed_up = Vector3.UP
	_sync_body(1.0)
	body.reset_physics_interpolation()
	ball.reset_physics_interpolation()
	_trail.clear()
	respawned.emit()


func _physics_process(delta: float) -> void:
	if controlled_by_player:
		_read_player_input()

	_grounded = _ground_ray.is_colliding()
	_ground_normal = _ground_ray.get_collision_normal() if _grounded else Vector3.UP
	var ground := _ground_ray.get_collider() as Node if _grounded else null
	_offroad = ground != null and ground.is_in_group(&"offroad")
	_boost_left = maxf(_boost_left - delta, 0.0)
	_tick_effects(delta)
	if _grounded:
		if _air_time > 0.45:
			Audio.play_at(&"land", body.global_position, -2.0 if _is_player_car else -8.0)
			jolted.emit(clampf(_air_time * 0.4, 0.15, 0.5))
		_air_time = 0.0
	else:
		_air_time += delta
	if _jumping:
		_jump_grace -= delta
		if _grounded and _jump_grace <= 0.0:
			_jumping = false

	var forward := _project_on_ground(get_forward())
	var right := forward.cross(_ground_normal).normalized()
	var velocity := ball.linear_velocity
	var speed := velocity.dot(forward)

	if is_spinning():
		# Під час розкрутки керування не працює.
		throttle_input = 0.0
		steer_input = 0.0
	_update_drift(speed, delta)
	_steer(speed, delta)
	if _yaw_kick != 0.0:
		_heading += _yaw_kick * delta
		_yaw_kick *= exp(-delta / YAW_KICK_TIME)
		if absf(_yaw_kick) < 0.01:
			_yaw_kick = 0.0
	if _grounded and not (_jumping and _jump_grace > 0.0):
		_drive(forward, right, velocity, speed, delta)

	if ball.global_position.y < fall_limit_y:
		respawn()
		return

	_sync_body(delta)
	_animate(speed, delta)


func _tick_effects(delta: float) -> void:
	_slow_left = maxf(_slow_left - delta, 0.0)
	_protect_left = maxf(_protect_left - delta, 0.0)
	_ghost_left = maxf(_ghost_left - delta, 0.0)
	if _steer_left > 0.0:
		_steer_left -= delta
		if _steer_left <= 0.0:
			_steer_multiplier = 1.0
	if _mass_left > 0.0:
		_mass_left -= delta
		if _mass_left <= 0.0:
			ball.mass = _base_mass
	if _spin_left > 0.0:
		_spin_left -= delta
		_heading += _spin_rate * delta
		if _spin_left <= 0.0:
			# Точно повертаємо курс, без похибки накопичення.
			_spin_left = 0.0
			_heading = _spin_end_heading


func _read_player_input() -> void:
	throttle_input = Input.get_axis(&"brake", &"accelerate")
	steer_input = Input.get_axis(&"steer_right", &"steer_left")
	if Input.is_action_just_pressed(&"respawn"):
		respawn()


func _steer(speed: float, delta: float) -> void:
	# На місці не повертаємо; повна швидкість повороту з ~5 м/с.
	var speed_factor := clampf(absf(speed) / 5.0, 0.0, 1.0)
	# На великій швидкості поворот трохи ширший — так стабільніше.
	var high_speed_factor := lerpf(1.0, high_speed_turn_factor, clampf(absf(speed) / max_speed, 0.0, 1.0))
	var direction := -1.0 if speed < -0.5 else 1.0
	var air := 1.0 if _grounded else (_jump_air_steer if _jumping else air_steer_factor)
	var drift_turn := 1.0 + (drift_turn_boost - 1.0) * _drift
	_heading += steer_input * turn_speed * _steer_multiplier * speed_factor * high_speed_factor * direction * air * drift_turn * delta


## Занос: на великій швидкості й при сильному повороті бокове зчеплення слабшає,
## машину виносить назовні повороту. Відпустив кермо чи скинув швидкість — зчеплення повертається.
func _update_drift(speed: float, delta: float) -> void:
	var target := 0.0
	if _grounded and not is_spinning() and speed > 0.0:
		var speed_ratio := speed / maxf(max_speed, 0.1)
		target = smoothstep(drift_speed_start, drift_speed_start + 0.15, speed_ratio) \
			* smoothstep(drift_steer_start, 1.0, absf(steer_input))
	_drift = move_toward(_drift, target, delta * (4.0 if target > _drift else 2.5))
	if not _grounded:
		_lateral_speed = 0.0


func _drive(forward: Vector3, right: Vector3, velocity: Vector3, speed: float, delta: float) -> void:
	var accel := 0.0
	var boost := _boost_multiplier if _boost_left > 0.0 else 1.0
	var slow := _slow_factor if _slow_left > 0.0 else 1.0
	var top_speed := max_speed * catchup_multiplier * boost * slow * (offroad_speed_factor if _offroad else 1.0)
	if throttle_input < 0.0:
		if speed > 0.5:
			accel = brake_decel * throttle_input
		elif speed > -reverse_speed:
			accel = acceleration * 0.6 * throttle_input
	elif speed > top_speed + 0.5:
		# Швидше за ліміт (наприклад, з'їхав на траву) — гальмуємо до нього.
		accel = -(offroad_decel if _offroad else coast_decel)
	elif throttle_input > 0.0:
		# Розгін плавно слабшає в останній чверті до максимуму.
		var headroom := clampf((top_speed - speed) / (top_speed * 0.25), 0.15, 1.0)
		# Під час турбо розганяємось помітно сильніше.
		accel = acceleration * accel_multiplier * throttle_input * headroom * (1.0 + (boost - 1.0) * 3.0)
	else:
		accel = -signf(speed) * minf(coast_decel, absf(speed) / delta)

	var lateral_speed := velocity.dot(right)
	_lateral_speed = lateral_speed
	var force := forward * accel - right * lateral_speed * lerpf(grip, drift_grip, _drift)
	if _drift > 0.0:
		force -= forward * signf(speed) * drift_scrub * absf(lateral_speed) * _drift
	ball.apply_central_force(force * ball.mass)


func _project_on_ground(direction: Vector3) -> Vector3:
	return (direction - _ground_normal * direction.dot(_ground_normal)).normalized()


func _sync_body(delta: float) -> void:
	body.global_position = ball.global_position - Vector3.UP * BALL_RADIUS
	var target_up := _ground_normal if _grounded else Vector3.UP
	_smoothed_up = _smoothed_up.lerp(target_up.normalized(), 1.0 - exp(-10.0 * delta)).normalized()
	var back := -get_forward()
	var x_axis := _smoothed_up.cross(back).normalized()
	var z_axis := x_axis.cross(_smoothed_up).normalized()
	body.global_basis = Basis(x_axis, _smoothed_up, z_axis)


func _animate(speed: float, delta: float) -> void:
	# Двигун: вища тональність на швидкості, ще вища під турбо.
	var rev := clampf(absf(speed) / max_speed, 0.0, 1.6)
	var target_pitch := 0.55 + rev * 1.1 + (0.25 if is_boosting() else 0.0) + (0.15 if not _grounded else 0.0)
	_engine.pitch_scale = lerpf(_engine.pitch_scale, target_pitch, 1.0 - exp(-6.0 * delta))
	_exhaust.visible = is_boosting()
	_jet_flame.visible = _jumping
	_shield.visible = is_protected()
	_slow_ring.visible = is_slowed()
	if _slow_ring.visible:
		_slow_ring.rotation.y += delta * 3.0
	# Привид мерехтить.
	_model.visible = not is_ghost() or fmod(Time.get_ticks_msec() / 1000.0, 0.2) < 0.13
	var speed_ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	var target_roll := -steer_input * speed_ratio * max_body_roll
	_model.rotation.z = lerpf(_model.rotation.z, target_roll, 1.0 - exp(-8.0 * delta))
	for wheel: Node3D in _front_wheels:
		wheel.rotation.y = lerpf(wheel.rotation.y, steer_input * max_wheel_angle, 1.0 - exp(-15.0 * delta))
	for spin: Node3D in _wheel_spins:
		spin.rotation.x = wrapf(spin.rotation.x - speed / 0.35 * delta, -PI, PI)
	# Дим з-під задніх коліс і вереск шин, поки машину несе вбік.
	var slide := clampf((absf(_lateral_speed) - 2.0) / 6.0, 0.0, 1.0) if _grounded else 0.0
	for smoke: CPUParticles3D in _smoke:
		smoke.emitting = slide > 0.15
	if slide > 0.05:
		_skid.volume_db = linear_to_db(slide) + (-8.0 if _is_player_car else -16.0)
		_skid.pitch_scale = 0.9 + slide * 0.2
		if not _skid.playing:
			_skid.play()
	elif _skid.playing:
		_skid.stop()
