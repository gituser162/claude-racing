class_name WindEffect
extends Node3D
## Ефект вітру на великій швидкості (дочірній вузол камери гравця).
## Сила росте разом зі швидкістю від start_kmh до full_kmh:
##  - світлі смуги летять повз камеру по краях кадру: що швидше, то їх більше,
##    вони яскравіші, довші, швидші й ближче до центру (другий, щільніший шар вмикається з середини);
##  - гул вітру стає гучнішим і вищим;
##  - на максимумі камеру ледь помітно трусить потоком повітря.

@export var car: Car
@export var start_kmh: float = 100.0
@export var full_kmh: float = 165.0

var _layers: Array[CPUParticles3D] = []
var _materials: Array[StandardMaterial3D] = []
var _sound: AudioStreamPlayer
var _strength: float = 0.0


func _ready() -> void:
	# Шар 0 — рідкі смуги з самого початку; шар 1 — щільні довгі смуги на великій швидкості.
	_add_layer(60, 3.0, 7.0, 3.0)
	_add_layer(110, 5.5, 6.0, 2.2)
	_sound = AudioStreamPlayer.new()
	_sound.stream = Audio.get_sound(&"wind_loop")
	_sound.bus = &"SFX"
	_sound.volume_db = -60.0
	add_child(_sound)


func _add_layer(amount: int, length: float, radius: float, inner_radius: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog = true
	material.albedo_color = Color(0.85, 0.9, 1.0, 0.0)
	mesh.material = material
	var streaks := CPUParticles3D.new()
	streaks.mesh = mesh
	streaks.amount = amount
	streaks.lifetime = 0.4
	streaks.local_coords = true
	streaks.emitting = false
	# Кільце навколо осі погляду: смуги йдуть по краях, не закриваючи дорогу.
	streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	streaks.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	streaks.emission_ring_radius = radius
	streaks.emission_ring_inner_radius = inner_radius
	streaks.emission_ring_height = 14.0
	streaks.position = Vector3(0.0, 0.0, -24.0)
	streaks.direction = Vector3(0.0, 0.0, 1.0)
	streaks.spread = 0.0
	streaks.gravity = Vector3.ZERO
	streaks.initial_velocity_min = 55.0
	streaks.initial_velocity_max = 85.0
	add_child(streaks)
	_layers.append(streaks)
	_materials.append(material)


func _process(delta: float) -> void:
	var kmh := absf(car.get_speed()) * 3.6 if car else 0.0
	var target := clampf((kmh - start_kmh) / (full_kmh - start_kmh), 0.0, 1.0)
	_strength = move_toward(_strength, target, delta * 2.5)
	# Шар 0: з'являється одразу після start_kmh.
	_layers[0].emitting = _strength > 0.02
	_materials[0].albedo_color.a = 0.12 + 0.43 * _strength
	_layers[0].speed_scale = 0.8 + 0.7 * _strength
	# Шар 1: вмикається з середини діапазону й швидко набирає яскравість.
	var dense := clampf((_strength - 0.35) / 0.65, 0.0, 1.0)
	_layers[1].emitting = dense > 0.02
	_materials[1].albedo_color.a = 0.6 * dense
	_layers[1].speed_scale = 0.9 + 0.8 * dense
	if _strength > 0.02:
		_sound.volume_db = linear_to_db(_strength) - 4.0
		_sound.pitch_scale = 0.9 + 0.35 * _strength
		if not _sound.playing:
			_sound.play()
	elif _sound.playing:
		_sound.stop()
	# Ледь помітне тремтіння від потоку повітря на найбільшій швидкості.
	var camera := get_parent() as ChaseCamera
	if camera and dense > 0.5:
		camera.add_shake((dense - 0.5) * 0.9 * delta)
