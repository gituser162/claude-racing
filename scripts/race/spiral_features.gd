extends Node3D
## Особливі місця мапи «Спіраль»: вежа, навколо якої траса спускається з даху на перший поверх.
## Будуються, коли траса вже готова (Track викликає build_features після свого _ready).
##  - Вежа (циліндр із вікнами), неонові смуги по фасаду, вогні на даху, щогла й вивіска.
##  - Спіральна рампа: колони під зовнішнім краєм, неонові лінії під плитою й по краю.
##  - Номери поверхів і реклама на стіні вежі вздовж рампи.
##  - Фініш на виході з вежі й відбійники-упори на початку й у кінці траси.
## Числа вежі мають збігатися з tools/spiral_layout.py (центр, радіуси, висота).

@export var tower_center: Vector2 = Vector2(-6.0, 0.0)
@export var tower_radius: float = 32.0
## Точка, де заїзд з даху переходить у спіраль (x, z) — від неї рахується спуск.
@export var spiral_start: Vector2 = Vector2(-33.33, -30.56)
@export var ring_radius: float = 41.0
@export var spiral_turns: float = 7.25
@export var column_spacing: float = 24.0
## Номер поверху й реклама на стіні вежі — через стільки метрів уздовж рампи.
@export var sign_spacing: float = 64.4

const GLOW_SHADER: Shader = preload("res://resources/shaders/psx_glow.gdshader")
const GRID_SHADER: Shader = preload("res://resources/shaders/grid.gdshader")
const FONT: Font = preload("res://assets/fonts/RubikGlitch-Regular.ttf")

var _track: Track
var _beacon: MeshInstance3D
var _sign: Node3D
var _time: float = 0.0


func build_features(track: Track) -> void:
	_track = track
	var start := _track.get_offset_of(Vector3(spiral_start.x, 0.0, spiral_start.y))
	var spiral_len := TAU * ring_radius * spiral_turns
	_build_tower()
	_build_ramp(start, start + spiral_len)
	_build_wall_signs(start, start + spiral_len)
	_build_roof()
	_build_finish()
	_build_end_walls()


func _process(delta: float) -> void:
	_time += delta
	if _beacon:
		_beacon.visible = fmod(_time, 1.2) < 0.25
	if _sign:
		_sign.rotate_y(delta * 0.25)


## Вежа: циліндр від землі до даху з вікнами (той самий шейдер, що й у міста) і неоновими смугами.
func _build_tower() -> void:
	var holder := Node3D.new()
	holder.name = "Tower"
	add_child(holder)
	var bottom := _track.floor_base_y
	var top := -0.3
	var cyl := CylinderMesh.new()
	cyl.top_radius = tower_radius
	cyl.bottom_radius = tower_radius
	cyl.height = top - bottom
	cyl.radial_segments = 40
	cyl.rings = 1
	var mat := ShaderMaterial.new()
	mat.shader = Track.BUILDING_SHADER
	mat.set_shader_parameter(&"lit_ratio", 0.45)
	mat.set_shader_parameter(&"ground_y", _track.floor_base_y)
	# Місто цієї мапи теж стоїть на землі далеко внизу — вікна до самого низу.
	var city := _track.get_node_or_null(^"City")
	if city and city.get_child_count() > 0:
		var city_mat := (city.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
		city_mat.set_shader_parameter(&"ground_y", _track.city_floor_y)
	_track._add_mesh(holder, cyl, mat, Vector3(tower_center.x, (top + bottom) * 0.5, tower_center.y))
	# Вертикальні неонові смуги по фасаду — видно між витками рампи.
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.5, top - bottom, 0.5)
	for i: int in 8:
		var angle := TAU * (i + 0.5) / 8.0
		var color := Track.NEON_COLORS[i % 2]
		var glow := _track._psx_material(color * 0.4, color, 2.5, false)
		glow.set_shader_parameter(&"detail_strength", 0.0)
		var p := Vector3(tower_center.x + cos(angle) * (tower_radius + 0.15), (top + bottom) * 0.5, tower_center.y + sin(angle) * (tower_radius + 0.15))
		_track._add_mesh(holder, stripe, glow, p)
	# Неонове кільце по краю даху.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = tower_radius - 0.25
	torus.outer_radius = tower_radius + 0.25
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _glow(Color(1.0, 0.2, 0.75), 2.0)
	ring.position = Vector3(tower_center.x, top - 0.6, tower_center.y)
	holder.add_child(ring)


## Рампа: колони під зовнішнім краєм (до витка вище, а під нижнім витком — до землі)
## і неонові лінії під плитою та вздовж її зовнішнього краю.
func _build_ramp(start: float, end: float) -> void:
	var holder := Node3D.new()
	holder.name = "Ramp"
	add_child(holder)
	var turn_len := TAU * ring_radius
	var column := BoxMesh.new()
	column.size = Vector3(0.9, 1.0, 0.9)
	var concrete := _track._psx_material(Color(0.2, 0.19, 0.23))
	var lateral := 8.1
	var offset := start + column_spacing * 0.5
	while offset < end:
		var t := _track.get_transform_at(offset, lateral)
		# Від дороги до низу плити витка вище (якщо він є над цим місцем).
		if offset - turn_len >= start:
			_add_column(holder, column, concrete, t.origin, t.origin.y, _track.get_transform_at(offset - turn_len, lateral).origin.y - 1.0)
		# Нижній виток: під плитою — до землі.
		if offset + turn_len > end and t.origin.y - 1.0 - _track.floor_base_y > 0.5:
			_add_column(holder, column, concrete, t.origin, _track.floor_base_y, t.origin.y - 1.0)
		offset += column_spacing
	# Неон: дві лінії під плитою (видно зі стелі витка нижче) і смуга на зовнішньому торці плити.
	var cyan := _track._psx_material(Color(0.05, 0.4, 0.5), Color(0.15, 0.9, 1.0), 3.0, false)
	cyan.set_shader_parameter(&"detail_strength", 0.0)
	var pink := _track._psx_material(Color(0.5, 0.05, 0.35), Color(1.0, 0.2, 0.75), 3.0, false)
	pink.set_shader_parameter(&"detail_strength", 0.0)
	_track._add_path_strip(holder, PackedVector2Array([Vector2(-4.2, -1.0), Vector2(-3.9, -1.0), Vector2(-3.9, -1.08), Vector2(-4.2, -1.08)]), cyan)
	_track._add_path_strip(holder, PackedVector2Array([Vector2(3.9, -1.0), Vector2(4.2, -1.0), Vector2(4.2, -1.08), Vector2(3.9, -1.08)]), pink)
	_track._add_path_strip(holder, PackedVector2Array([Vector2(8.6, -0.25), Vector2(8.68, -0.25), Vector2(8.68, -0.6), Vector2(8.6, -0.6)]), pink)


func _add_column(holder: Node3D, mesh: Mesh, mat: Material, at: Vector3, from_y: float, to_y: float) -> void:
	var node := _track._add_mesh(holder, mesh, mat, Vector3(at.x, (from_y + to_y) * 0.5, at.z))
	node.scale.y = to_y - from_y


## Номери поверхів і вигадана реклама на стіні вежі, повернуті до рампи.
func _build_wall_signs(start: float, end: float) -> void:
	var holder := Node3D.new()
	holder.name = "WallSigns"
	add_child(holder)
	var panel := BoxMesh.new()
	panel.size = Vector3(9.0, 3.4, 0.3)
	var dark := _track._psx_material(Color(0.03, 0.02, 0.06), Color(0.06, 0.02, 0.1), 1.0, false)
	var i := 0
	var offset := start + 20.0
	while offset < end - 10.0:
		var t := _track.get_transform_at(offset)
		var floor_number := _track.get_floor(t.origin)
		# Обличчям (+Z) — від стіни до дороги (праворуч від руху — назовні спіралі).
		var basis := t.basis * Basis(Vector3.UP, PI * 0.5)
		var wall := t.origin - t.basis.x * (_track.road_width * 0.5 + 2.0)
		var number := _label("%d" % floor_number, 220, Track.NEON_COLORS[i % 2].lightened(0.2))
		number.double_sided = false
		number.transform = Transform3D(basis, wall + Vector3.UP * 5.0 + basis.z * 0.3)
		holder.add_child(number)
		var word := _label("ПОВЕРХ", 70, Color(0.9, 0.9, 1.0))
		word.double_sided = false
		word.transform = Transform3D(basis, wall + Vector3.UP * 2.0 + basis.z * 0.3)
		holder.add_child(word)
		# Реклама — між номерами поверхів.
		var ad_t := _track.get_transform_at(offset + sign_spacing * 0.5)
		var ad_basis := ad_t.basis * Basis(Vector3.UP, PI * 0.5)
		var ad_pos := ad_t.origin - ad_t.basis.x * (_track.road_width * 0.5 + 2.0) + Vector3.UP * 4.5
		if offset + sign_spacing * 0.5 < end - 10.0:
			var board := Node3D.new()
			board.transform = Transform3D(ad_basis, ad_pos)
			holder.add_child(board)
			var color := Track.NEON_COLORS[(i * 3 + 2) % Track.NEON_COLORS.size()]
			var frame := BoxMesh.new()
			frame.size = Vector3(9.6, 4.0, 0.2)
			_track._add_mesh(board, frame, _track._psx_material(color * 0.3, color, 2.0, false), Vector3(0, 0, 0.05))
			_track._add_mesh(board, panel, dark, Vector3(0, 0, 0.25))
			var text := Label3D.new()
			text.text = Track.ADS[i % Track.ADS.size()]
			text.font_size = 72
			text.pixel_size = 0.015
			text.modulate = color.lightened(0.3)
			text.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			text.shaded = false
			text.double_sided = false
			text.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			text.outline_size = 12
			text.outline_modulate = Color(0.02, 0.0, 0.05)
			text.position = Vector3(0, 0, 0.45)
			board.add_child(text)
		offset += sign_spacing
		i += 1


## Дах: щогла з проблисковим вогнем і обертова неонова вивіска над вежею.
func _build_roof() -> void:
	var holder := Node3D.new()
	holder.name = "Roof"
	add_child(holder)
	var metal := _track._psx_material(Color(0.25, 0.25, 0.3))
	var mast := BoxMesh.new()
	mast.size = Vector3(0.8, 26.0, 0.8)
	# Праворуч від стартової прямої, на вільній частині даху.
	var mast_pos := Vector3(tower_center.x + 14.0, 0.0, tower_center.y + 4.0)
	_track._add_mesh(holder, mast, metal, mast_pos + Vector3.UP * 12.7)
	var lamp := SphereMesh.new()
	lamp.radius = 0.7
	lamp.height = 1.4
	_beacon = _track._add_mesh(holder, lamp, _glow(Color(1.0, 0.1, 0.1), 3.0), mast_pos + Vector3.UP * 26.2)
	# Вивіска над вежею: видно з даху на старті й з міста.
	_sign = Node3D.new()
	_sign.position = Vector3(tower_center.x, 34.0, tower_center.y)
	holder.add_child(_sign)
	for side: float in [0.0, PI]:
		var title := _label("СПІРАЛЬ", 520, Color(1.0, 0.3, 0.8))
		title.rotation.y = side
		title.double_sided = false
		_sign.add_child(title)
		var sub := _label("28 ПОВЕРХІВ ВНИЗ", 160, Color(0.4, 0.95, 1.0))
		sub.rotation.y = side
		sub.double_sided = false
		sub.position.y = -6.5
		_sign.add_child(sub)


## Фініш на виході з вежі: смуга «шахівниця» і арка з написом.
func _build_finish() -> void:
	var t := _track.get_transform_at(_track.finish_offset)
	var holder := Node3D.new()
	holder.name = "Finish"
	holder.transform = t
	add_child(holder)
	var line := BoxMesh.new()
	line.size = Vector3(_track.road_width, 0.04, 2.0)
	var checker := ShaderMaterial.new()
	checker.shader = GRID_SHADER
	checker.set_shader_parameter(&"color_a", Color(0.8, 0.8, 0.8))
	checker.set_shader_parameter(&"color_b", Color(0.05, 0.05, 0.05))
	checker.set_shader_parameter(&"cell_size", 1.0)
	_track._add_mesh(holder, line, checker, Vector3(0.0, 0.02, 0.0))
	var post := BoxMesh.new()
	post.size = Vector3(0.8, 7.0, 0.8)
	var metal := _track._psx_material(Color(0.12, 0.12, 0.14))
	for side: float in [-1.0, 1.0]:
		_track._add_mesh(holder, post, metal, Vector3(side * 9.5, 3.5, 0.0))
	var banner := BoxMesh.new()
	banner.size = Vector3(20.0, 1.6, 0.6)
	_track._add_mesh(holder, banner, _track._psx_material(Color(0.05, 0.3, 0.35), Color(0.15, 0.9, 1.0), 1.5), Vector3(0.0, 7.2, 0.0))
	var label := _label("ФІНІШ", 110, Color(1.0, 1.0, 1.0))
	label.position = Vector3(0.0, 7.2, 0.5)
	holder.add_child(label)


## Упор у кінці зони гальмування за фінішем (за стартовою сіткою упору немає — він закривав би огляд;
## хто здасть назад з даху, той респавниться, див. Track.respawn_off_road).
func _build_end_walls() -> void:
	var concrete := _track._psx_material(Color(0.32, 0.31, 0.34))
	var neon := _track._psx_material(Color(0.4, 0.3, 0.05), Color(1.0, 0.85, 0.2), 2.4, false)
	neon.set_shader_parameter(&"detail_strength", 0.0)
	var block := BoxMesh.new()
	block.size = Vector3(_track.road_width + 1.0, 1.2, 0.8)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(_track.road_width + 1.02, 0.2, 0.82)
	for at: float in [_track.length - 0.4]:
		var t := _track.get_transform_at(at)
		var wall := StaticBody3D.new()
		wall.name = "EndWall"
		wall.collision_layer = Track.BARRIER_LAYER
		wall.collision_mask = 0
		wall.add_to_group(&"barrier")
		wall.transform = t
		add_child(wall)
		_track._add_mesh(wall, block, concrete, Vector3(0.0, 0.6, 0.0))
		_track._add_mesh(wall, stripe, neon, Vector3(0.0, 0.95, 0.0))
		var shape := BoxShape3D.new()
		shape.size = Vector3(_track.road_width + 1.0, 1.4, 0.8)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(0.0, 0.7, 0.0)
		wall.add_child(collider)


func _glow(color: Color, intensity: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"intensity", intensity)
	mat.set_shader_parameter(&"rim", false)
	return mat


func _label(text: String, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = font_size
	label.pixel_size = 0.02
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.0, 0.08)
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.shaded = false
	return label
