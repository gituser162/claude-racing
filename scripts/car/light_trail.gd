extends MeshInstance3D
## Світлові сліди задніх вогнів на швидкості (кіберпанк-ефект).
## Зберігає останні позиції двох вогнів і малює з них дві стрічки, що згасають до хвоста.

const GLOW_SHADER: Shader = preload("res://resources/shaders/psx_glow.gdshader")

## Від якої швидкості (м/с) з'являються сліди і коли вони на повну яскравість.
@export var min_speed: float = 18.0
@export var full_speed: float = 30.0
@export var length_points: int = 14
@export var width: float = 0.16

var car: Car
var _left: Array[Vector3] = []
var _right: Array[Vector3] = []
var _strength: float = 0.0
var _immediate: ImmediateMesh


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter(&"color", Color(1.0, 0.12, 0.15))
	mat.set_shader_parameter(&"intensity", 1.4)
	mat.set_shader_parameter(&"rim", false)
	material_override = mat
	extra_cull_margin = 100.0


func _physics_process(_delta: float) -> void:
	if car == null:
		return
	var speed := car.get_speed()
	_strength = clampf((speed - min_speed) / (full_speed - min_speed), 0.0, 1.0)
	var basis := car.body.global_basis
	var rear := car.body.global_position + basis.z * (car.footprint.y * 0.5) + basis.y * 0.5
	var side := basis.x * (car.footprint.x * 0.35)
	_left.push_front(rear - side)
	_right.push_front(rear + side)
	if _left.size() > length_points:
		_left.pop_back()
		_right.pop_back()
	_rebuild()


## Очищує сліди (після респауну чи телепорту, щоб не було «стрічки через усю трасу»).
func clear() -> void:
	_left.clear()
	_right.clear()
	_immediate.clear_surfaces()


func _rebuild() -> void:
	_immediate.clear_surfaces()
	if _strength <= 0.0 or _left.size() < 2:
		return
	for points: Array[Vector3] in [_left, _right]:
		_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i: int in points.size():
			var fade := (1.0 - float(i) / points.size()) * _strength
			var c := Color(fade, fade, fade)
			var up := Vector3.UP * width * (1.0 - float(i) / points.size())
			_immediate.surface_set_color(c)
			_immediate.surface_add_vertex(points[i] + up)
			_immediate.surface_set_color(c)
			_immediate.surface_add_vertex(points[i] - up)
		_immediate.surface_end()
