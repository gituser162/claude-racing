extends Node3D
## Зграя гусей (ультімейт Гусака): летить уздовж траси зі швидкістю speed
## і розкручує всі машини, які наздоганяє (крім гусака-власника).

@export var speed: float = 48.0
@export var max_distance: float = 180.0
@export var height: float = 2.2

var track: Track
var source_car: Car
var start_offset: float = 0.0

var _travelled: float = 0.0
var _hit: Array[Car] = []
var _geese: Array[Node3D] = []


func _ready() -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.5, 0.35, 0.9)
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(1.4, 0.05, 0.4)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://resources/shaders/psx.gdshader")
	mat.set_shader_parameter(&"albedo", Color(0.85, 0.85, 0.8))
	mat.set_shader_parameter(&"emission", Color(1.0, 0.95, 0.85))
	mat.set_shader_parameter(&"emission_energy", 0.6)
	# Клин: ватажок попереду, решта позаду обабіч.
	var slots := [Vector3(0, 0, 0), Vector3(-1.6, 0.2, 1.4), Vector3(1.6, 0.2, 1.4),
		Vector3(-3.2, 0.4, 2.8), Vector3(3.2, 0.4, 2.8)]
	for slot: Vector3 in slots:
		var goose := Node3D.new()
		goose.position = slot
		var b := MeshInstance3D.new()
		b.mesh = body_mesh
		b.material_override = mat
		var wing := MeshInstance3D.new()
		wing.mesh = wing_mesh
		wing.material_override = mat
		wing.name = "Wing"
		goose.add_child(b)
		goose.add_child(wing)
		add_child(goose)
		_geese.append(goose)
	_place()


func _physics_process(delta: float) -> void:
	_travelled += speed * delta
	_place()
	var flap := sin(Time.get_ticks_msec() / 60.0)
	for goose: Node3D in _geese:
		goose.get_node("Wing").rotation.z = flap * 0.5
	var my_offset := track.wrap_offset(start_offset + _travelled)
	for car: Car in source_car.skills.cars:
		if car == source_car or car in _hit:
			continue
		var d := track.signed_gap(my_offset, track.get_offset_of(car.body.global_position))
		if absf(d) < 4.0:
			_hit.append(car)
			car.spin_out(1.0)
	if _travelled > max_distance:
		queue_free()


func _place() -> void:
	global_transform = track.get_transform_at(start_offset + _travelled, 0.0, height)
