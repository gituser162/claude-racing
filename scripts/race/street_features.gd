extends Node3D
## Особливі місця мапи «Міська вулиця». Будуються, коли траса вже готова
## (Track викликає build_features після свого _ready).
##  - Неоновий тунель під хмарочосом: дах, стіни, світлові смуги, портали з вивісками.
##  - Ринкова шикана: гірлянди ліхтариків і вивіски вигаданих крамниць над вузькою вулицею.
##  - Площа з голограмою: у шпильці — величезна обертова голограма кота-буханки на постаменті.
## Ділянки задаються точками світу (x, z) — так їх легко пересунути, якщо зміниться крива траси.

@export var tunnel_from: Vector2 = Vector2(281.0, -36.25)
@export var tunnel_to: Vector2 = Vector2(108.0, -36.25)
@export var market_from: Vector2 = Vector2(217.5, -290.0)
@export var market_to: Vector2 = Vector2(304.5, -195.0)
@export var plaza_center: Vector3 = Vector3(177.6, 0.0, -330.0)

const GLOW_SHADER: Shader = preload("res://resources/shaders/psx_glow.gdshader")
const BEAM_SHADER: Shader = preload("res://resources/shaders/light_beam.gdshader")
const HOLOGRAM_SHADER: Shader = preload("res://resources/shaders/hologram.gdshader")
## Вигадані крамниці на ринку (без справжніх брендів).
const SHOPS: Array[String] = [
	"ЛОКШИНА 24/7", "РЕМОНТ ДРОНІВ", "КІБЕР-ЧАЙ", "ВАРЕНИКИ", "ЗАПЧАСТИНИ\nДЛЯ МАРШРУТОК",
	"НЕОН-ШАУРМА", "ГУСИ НЕ ГОДУВАТИ", "КАВА З АВТОМАТА", "ХОЛОДЕЦЬ 2.0", "ЧИП-ТЮНІНГ КРІСЕЛ",
]

var _track: Track
var _hologram: Node3D


func build_features(track: Track) -> void:
	_track = track
	_build_tunnel(_offset_at(tunnel_from), _offset_at(tunnel_to))
	_build_market(_offset_at(market_from), _offset_at(market_to))
	_build_plaza()


func _process(delta: float) -> void:
	if _hologram:
		_hologram.rotate_y(delta * 0.6)
		_hologram.position.y = 10.0 + sin(Time.get_ticks_msec() / 900.0) * 0.6


func _offset_at(point: Vector2) -> float:
	return _track.get_offset_of(Vector3(point.x, 0.0, point.y))


## Обходить ділянку траси від a до b (з урахуванням переходу через старт) з кроком step.
func _offsets(a: float, b: float, step: float) -> PackedFloat32Array:
	if b < a:
		b += _track.length
	var result := PackedFloat32Array()
	var offset := a
	while offset <= b:
		result.append(fposmod(offset, _track.length))
		offset += step
	return result


func _build_tunnel(a: float, b: float) -> void:
	var holder := Node3D.new()
	holder.name = "Tunnel"
	add_child(holder)
	var half := _track.road_width * 0.5
	var step := 3.0
	var roof := BoxMesh.new()
	roof.size = Vector3(_track.road_width + 3.0, 1.2, step + 0.05)
	var wall := BoxMesh.new()
	wall.size = Vector3(0.8, 7.5, step + 0.05)
	var lamp := BoxMesh.new()
	lamp.size = Vector3(_track.road_width * 0.55, 0.12, 0.6)
	var strip := BoxMesh.new()
	strip.size = Vector3(0.1, 0.18, step + 0.05)
	var concrete := _track._psx_material(Color(0.16, 0.15, 0.18))
	var ceiling_light := _track._psx_material(Color(0.8, 0.9, 1.0), Color(0.7, 0.9, 1.0), 3.0, false)
	ceiling_light.set_shader_parameter(&"detail_strength", 0.0)
	var cyan := _track._psx_material(Color(0.05, 0.4, 0.5), Color(0.15, 0.9, 1.0), 3.0, false)
	cyan.set_shader_parameter(&"detail_strength", 0.0)
	var pink := _track._psx_material(Color(0.5, 0.05, 0.35), Color(1.0, 0.2, 0.75), 3.0, false)
	pink.set_shader_parameter(&"detail_strength", 0.0)
	var i := 0
	for offset: float in _offsets(a, b, step):
		var t := _track.get_transform_at(offset)
		var seg := Node3D.new()
		seg.transform = t
		holder.add_child(seg)
		_track._add_mesh(seg, roof, concrete, Vector3(0.0, 8.1, 0.0))
		for side: float in [-1.0, 1.0]:
			_track._add_mesh(seg, wall, concrete, Vector3(side * (half + 0.9), 3.75, 0.0))
			# Неонові смуги вздовж стін: бірюзова ліворуч, рожева праворуч, дві висоти.
			_track._add_mesh(seg, strip, cyan if side < 0.0 else pink, Vector3(side * (half + 0.48), 1.6, 0.0))
			_track._add_mesh(seg, strip, cyan if side < 0.0 else pink, Vector3(side * (half + 0.48), 5.8, 0.0))
		if i % 3 == 0:
			_track._add_mesh(seg, lamp, ceiling_light, Vector3(0.0, 7.45, 0.0))
		i += 1
	# Хмарочос над тунелем.
	var mid := _track.get_transform_at(fposmod(a + _wrap_len(a, b) * 0.5, _track.length))
	var tower := MeshInstance3D.new()
	tower.mesh = BoxMesh.new()
	var building_mat := ShaderMaterial.new()
	building_mat.shader = Track.BUILDING_SHADER
	tower.material_override = building_mat
	var size := Vector3(_track.road_width + 14.0, 60.0, _wrap_len(a, b) - 10.0)
	tower.transform = Transform3D(mid.basis.scaled(size), mid.origin + Vector3.UP * (8.7 + size.y * 0.5))
	holder.add_child(tower)
	# Портали з вивісками на обох кінцях.
	for end: Array in [[a, "НЕОНОВИЙ ТУНЕЛЬ"], [b, "ВИХІД — ОБЕРЕЖНО, ПОВОРОТ"]]:
		var pt := _track.get_transform_at(end[0])
		var portal := Node3D.new()
		portal.transform = pt
		holder.add_child(portal)
		var frame := BoxMesh.new()
		frame.size = Vector3(_track.road_width + 2.0, 1.0, 0.4)
		_track._add_mesh(portal, frame, pink if end[0] == a else cyan, Vector3(0.0, 7.0, 0.0))
		var label := _label(end[1], 72, Color(1.0, 0.95, 1.0))
		label.position = Vector3(0.0, 7.0, 0.25 if end[0] == a else -0.25)
		if end[0] == b:
			label.rotation.y = PI
		portal.add_child(label)


func _wrap_len(a: float, b: float) -> float:
	return b - a if b >= a else b + _track.length - a


func _build_market(a: float, b: float) -> void:
	var holder := Node3D.new()
	holder.name = "Market"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var half := _track.road_width * 0.5
	var wire := BoxMesh.new()
	wire.size = Vector3(_track.road_width + 8.0, 0.05, 0.05)
	var wire_mat := _track._psx_material(Color(0.05, 0.05, 0.06))
	var lantern := BoxMesh.new()
	lantern.size = Vector3(0.45, 0.6, 0.45)
	var lantern_mats: Array[ShaderMaterial] = []
	for color: Color in Track.NEON_COLORS:
		var m := _track._psx_material(color * 0.3, color, 2.6, false)
		m.set_shader_parameter(&"detail_strength", 0.2)
		lantern_mats.append(m)
	var shop := 0
	var i := 0
	for offset: float in _offsets(a, b, 6.0):
		var t := _track.get_transform_at(offset)
		var row := Node3D.new()
		row.transform = t
		holder.add_child(row)
		var height := rng.randf_range(6.5, 8.0)
		_track._add_mesh(row, wire, wire_mat, Vector3(0.0, height, 0.0))
		# Ліхтарики на дроті — провисають до середини.
		for k: int in 7:
			var x := (k - 3) * (_track.road_width + 4.0) / 7.0
			var sag := 1.2 * (1.0 - pow(x / (half + 2.0), 2.0))
			_track._add_mesh(row, lantern, lantern_mats[rng.randi() % lantern_mats.size()], Vector3(x, height - 0.4 - sag, 0.0))
		# Вивіски крамниць по черзі з обох боків.
		if i % 2 == 0:
			var side := 1.0 if (i / 2) % 2 == 0 else -1.0
			var color := Track.NEON_COLORS[rng.randi() % Track.NEON_COLORS.size()]
			var board := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.3, 2.4, 5.5)
			board.mesh = bm
			board.material_override = _track._psx_material(color * 0.25, color, 1.6, false)
			board.position = Vector3(side * (half + 3.0), 4.6, 0.0)
			row.add_child(board)
			var label := _label(SHOPS[shop % SHOPS.size()], 44, Color(1.0, 1.0, 1.0))
			label.position = Vector3(side * (half + 2.82), 4.6, 0.0)
			label.rotation.y = -side * PI * 0.5
			row.add_child(label)
			shop += 1
		i += 1


func _build_plaza() -> void:
	var holder := Node3D.new()
	holder.name = "Plaza"
	add_child(holder)
	holder.position = plaza_center
	# Постамент і неонове кільце.
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 6.0
	cyl.bottom_radius = 6.5
	cyl.height = 1.6
	cyl.radial_segments = 12
	base.mesh = cyl
	base.material_override = _track._psx_material(Color(0.2, 0.19, 0.23))
	base.position.y = 0.8
	holder.add_child(base)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.1
	torus.outer_radius = 6.5
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = GLOW_SHADER
	ring_mat.set_shader_parameter(&"color", Color(0.2, 0.9, 1.0))
	ring_mat.set_shader_parameter(&"intensity", 2.0)
	ring_mat.set_shader_parameter(&"rim", false)
	ring.material_override = ring_mat
	ring.position.y = 1.65
	holder.add_child(ring)
	# Промінь проєктора вгору.
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 1.0
	cone.bottom_radius = 7.0
	cone.height = 14.0
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	beam.mesh = cone
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = BEAM_SHADER
	beam_mat.set_shader_parameter(&"color", Color(0.3, 0.9, 1.0))
	beam_mat.set_shader_parameter(&"intensity", 0.04)
	beam_mat.set_shader_parameter(&"falloff", 1.4)
	beam_mat.set_shader_parameter(&"fade_far", 260.0)
	beam.material_override = beam_mat
	# Джерело (верх циліндра) — на постаменті, конус розширюється вгору.
	beam.rotation.x = PI
	beam.position.y = 1.6 + 7.0
	holder.add_child(beam)
	# Голограма: модель кота-буханки, збільшена й «світна».
	_hologram = Node3D.new()
	_hologram.position.y = 10.0
	holder.add_child(_hologram)
	var cat: Node3D = load("res://scenes/racers/cat/model.tscn").instantiate()
	cat.scale = Vector3.ONE * 10.0
	_hologram.add_child(cat)
	var holo := ShaderMaterial.new()
	holo.shader = HOLOGRAM_SHADER
	holo.set_shader_parameter(&"color", Color(0.25, 0.85, 1.0))
	holo.set_shader_parameter(&"intensity", 0.9)
	for node: Node in cat.find_children("*", "GeometryInstance3D", true, false):
		if node is Label3D:
			(node as Label3D).modulate = Color(0.4, 0.9, 1.0, 0.7)
		else:
			(node as GeometryInstance3D).material_override = holo
	var title := _label("ДРИФТ-ЗОНА", 140, Color(1.0, 0.4, 0.85))
	title.position = Vector3(0.0, 20.0, 0.0)
	title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	holder.add_child(title)


func _label(text: String, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = preload("res://assets/fonts/RubikGlitch-Regular.ttf")
	label.font_size = font_size
	label.pixel_size = 0.02
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.0, 0.08)
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.shaded = false
	return label
