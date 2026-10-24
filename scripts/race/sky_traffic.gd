extends Node3D
## Аеромобілі над нічним містом: летять прямими «коридорами» на різній висоті,
## за межами міста повертаються з іншого боку. Лише декор, без колізій.

@export var count: int = 45
@export var area: AABB = AABB(Vector3(-220, 12, -460), Vector3(710, 70, 700))
@export var seed: int = 11

const PSX_SHADER: Shader = preload("res://resources/shaders/psx.gdshader")

var _cars: Array[Node3D] = []
var _velocities: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.8, 0.6, 4.0)
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(1.6, 0.15, 0.1)
	var body_mat := _mat(Color(0.08, 0.08, 0.1), Color.BLACK, 0.0)
	var head_mat := _mat(Color(1, 1, 0.9), Color(1, 0.95, 0.8), 3.0)
	var tail_mat := _mat(Color(0.8, 0, 0), Color(1, 0.05, 0.1), 3.0)
	var glow_mats: Array[ShaderMaterial] = [
		_mat(Color.BLACK, Color(0.2, 0.9, 1.0), 2.0), _mat(Color.BLACK, Color(1.0, 0.2, 0.7), 2.0)]
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(1.4, 0.05, 3.2)
	for i: int in count:
		var car := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = body_mat
		var head := MeshInstance3D.new()
		head.mesh = light_mesh
		head.material_override = head_mat
		head.position = Vector3(0, 0, -2.05)
		var tail := MeshInstance3D.new()
		tail.mesh = light_mesh
		tail.material_override = tail_mat
		tail.position = Vector3(0, 0, 2.05)
		var glow := MeshInstance3D.new()
		glow.mesh = glow_mesh
		glow.material_override = glow_mats[i % 2]
		# Неонова пластина помітно нижче корпусу — щоб не «мерехтіла» крізь днище.
		glow.position = Vector3(0, -0.75, 0)
		for part: Node3D in [body, head, tail, glow]:
			car.add_child(part)
		# Коридори вздовж осей X або Z (як вулиці), швидкість 20–45 м/с.
		var along_x := rng.randf() < 0.5
		var dir := (Vector3.RIGHT if along_x else Vector3.FORWARD) * (1.0 if rng.randf() < 0.5 else -1.0)
		car.position = area.position + Vector3(rng.randf() * area.size.x, rng.randf() * area.size.y, rng.randf() * area.size.z)
		car.basis = Basis.looking_at(dir, Vector3.UP)
		add_child(car)
		_cars.append(car)
		_velocities.append(dir * rng.randf_range(20.0, 45.0))


func _process(delta: float) -> void:
	var lo := area.position
	var hi := area.end
	for i: int in _cars.size():
		var car := _cars[i]
		var p := car.position + _velocities[i] * delta
		p.x = lo.x + fposmod(p.x - lo.x, hi.x - lo.x)
		p.z = lo.z + fposmod(p.z - lo.z, hi.z - lo.z)
		car.position = p


func _mat(albedo: Color, emission: Color, energy: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	m.set_shader_parameter(&"albedo", albedo)
	m.set_shader_parameter(&"emission", emission)
	m.set_shader_parameter(&"emission_energy", energy)
	# Далекі дрібні об'єкти з PS1-«тремтінням» мерехтять — для аеромобілів вимикаємо.
	m.set_shader_parameter(&"snap_grid", Vector2.ZERO)
	return m
