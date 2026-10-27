class_name WindEffect
extends Node3D
## Ефект вітру на великій швидкості (дочірній вузол камери гравця):
## тонкі світлі смуги летять повз камеру по краях кадру, центр лишається чистим,
## плюс гул вітру. З'являється від start_kmh і посилюється до full_kmh.

@export var car: Car
@export var start_kmh: float = 100.0
@export var full_kmh: float = 150.0

var _streaks: CPUParticles3D
var _material: StandardMaterial3D
var _sound: AudioStreamPlayer
var _strength: float = 0.0


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, 3.0)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.disable_fog = true
	_material.albedo_color = Color(0.85, 0.9, 1.0, 0.0)
	mesh.material = _material
	_streaks = CPUParticles3D.new()
	_streaks.mesh = mesh
	_streaks.amount = 70
	_streaks.lifetime = 0.4
	_streaks.local_coords = true
	_streaks.emitting = false
	# Кільце навколо осі погляду: смуги йдуть по краях, не закриваючи дорогу.
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_streaks.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	_streaks.emission_ring_radius = 7.0
	_streaks.emission_ring_inner_radius = 2.8
	_streaks.emission_ring_height = 14.0
	_streaks.position = Vector3(0.0, 0.0, -24.0)
	_streaks.direction = Vector3(0.0, 0.0, 1.0)
	_streaks.spread = 0.0
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 55.0
	_streaks.initial_velocity_max = 80.0
	add_child(_streaks)
	_sound = AudioStreamPlayer.new()
	_sound.stream = Audio.get_sound(&"wind_loop")
	_sound.bus = &"SFX"
	_sound.volume_db = -60.0
	add_child(_sound)


func _process(delta: float) -> void:
	var kmh := absf(car.get_speed()) * 3.6 if car else 0.0
	var target := clampf((kmh - start_kmh) / (full_kmh - start_kmh), 0.0, 1.0)
	_strength = move_toward(_strength, target, delta * 2.0)
	_streaks.emitting = _strength > 0.02
	_material.albedo_color.a = 0.08 + 0.3 * _strength
	_streaks.speed_scale = 0.8 + 0.4 * _strength
	if _strength > 0.02:
		_sound.volume_db = linear_to_db(_strength) - 10.0
		if not _sound.playing:
			_sound.play()
	elif _sound.playing:
		_sound.stop()
