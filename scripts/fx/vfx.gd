class_name Vfx
extends RefCounted
## Короткі світлові ефекти для скілів: спалах-куля і ударна хвиля-кільце.
## Створюють тимчасовий вузол у поточній сцені, анімують і самі видаляються.
##   Vfx.burst(self, позиція, колір)  — спалах (телепорт, влучання)
##   Vfx.ring(self, позиція, колір, радіус) — кільце, що розходиться (поштовх, «черга»)

const GLOW_SHADER: Shader = preload("res://resources/shaders/psx_glow.gdshader")


static func burst(context: Node, position: Vector3, color: Color, radius: float = 2.2, time: float = 0.45) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	_spawn(context, mesh, position, color, Vector3.ONE * 0.3, Vector3.ONE * radius, time, 2.2)


static func ring(context: Node, position: Vector3, color: Color, radius: float = 7.0, time: float = 0.5) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	mesh.rings = 24
	mesh.ring_segments = 4
	var start := Vector3(0.5, 1.0, 0.5)
	var finish := Vector3(radius, 1.0, radius)
	_spawn(context, mesh, position + Vector3.UP * 0.4, color, start, finish, time, 3.0)


static func _spawn(context: Node, mesh: Mesh, position: Vector3, color: Color,
		from_scale: Vector3, to_scale: Vector3, time: float, intensity: float) -> void:
	var scene := context.get_tree().current_scene
	if scene == null:
		return
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"intensity", intensity)
	mat.set_shader_parameter(&"rim", mesh is SphereMesh)
	node.material_override = mat
	node.scale = from_scale
	scene.add_child(node)
	node.global_position = position
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", to_scale, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"intensity", v), intensity, 0.0, time)
	tween.chain().tween_callback(node.queue_free)
