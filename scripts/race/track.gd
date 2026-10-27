class_name Track
extends Node3D
## Траса, побудована вздовж кривої TrackPath (Path3D).
## Дорогу малює CSGPolygon3D по цій кривій. Скрипт додає чекпоінти й декор
## і вміє переводити «відстань уздовж траси» у точку світу (для старту, респауну, ботів).

signal checkpoint_passed(car: Car, index: int)

@export var checkpoint_count: int = 16
@export var road_width: float = 14.0
## true — естакада над містом (опори, місто внизу, з траси можна впасти);
## false — вулиця на рівні землі (без опор, місто навколо траси).
@export var elevated: bool = true

@export_group("Тип траси")
## true — замкнене коло (старт = фініш); false — «спринт» від старту до фінішу (див. start_offset, finish_runout).
@export var closed: bool = true
## Спринт: де на кривій лінія старту, м від початку кривої (позаду неї — стартова сітка).
@export var start_offset: float = 0.0
## Спринт: скільки кривої лишається після лінії фінішу (зона гальмування), м.
@export var finish_runout: float = 0.0
## Машина нижче цієї висоти — респаун (для високих трас — нижче землі міста).
@export var fall_limit_y: float = -12.0
## Респаун, щойно машина опинилась далеко збоку від дороги (вилетіла за відбійник у прірву).
@export var respawn_off_road: bool = false
## Висота поверху, м (0 — без поверхів). Тоді на HUD замість кола — поверх (див. get_floor).
@export var floor_height: float = 0.0
## Висота підлоги першого поверху (землі під вежею).
@export var floor_base_y: float = 0.0

@export_group("Місто")
@export var city_seed: int = 7
@export var building_count: int = 260
@export var city_area: AABB = AABB(Vector3(-220, 0, -460), Vector3(710, 0, 700))
## Мінімальний вільний простір від краю дороги до будинку, м.
@export var street_margin: float = 9.0
@export var lamp_spacing: float = 36.0
## Висота «землі» міста під естакадою.
@export var city_floor_y: float = -40.0
@export var pillar_spacing: float = 30.0
@export var arch_spacing: float = 160.0
@export var billboard_spacing: float = 115.0
## Відстань білбордів від центру дороги, м.
@export var billboard_lateral: float = 19.0
## Будинки «фасадом» уздовж обох боків траси (як на справжній вулиці).
@export var frontage_buildings: bool = false
## Ширина тротуару між краєм дороги й фасадами, м.
@export var sidewalk_width: float = 5.0
## Зони без забудови: (x, z, радіус) — наприклад, площа всередині повороту.
@export var keep_clear: PackedVector3Array = PackedVector3Array()
## Де в меню стоїть подіум з моделлю гонщика (на дорозі біля старту).
@export var menu_showcase: Vector3 = Vector3(0.0, 0.0, -30.0)

@export_group("Бар'єри")
## SHARP_CORNERS — лише із зовнішнього боку крутих поворотів (естакада);
## FULL — суцільна стіна з обох боків уздовж усієї траси (вулиця, відбійники).
enum BarrierMode { SHARP_CORNERS, FULL }
@export var barrier_mode: BarrierMode = BarrierMode.SHARP_CORNERS
## Бар'єри ставляться із зовнішнього боку поворотів, крутіших за цей радіус, м.
@export var barrier_max_radius: float = 45.0
## Запас бар'єра до й після крутої ділянки, м.
@export var barrier_margin: float = 14.0

## Вигадана реклама на білбордах (без справжніх брендів).
const ADS: Array[String] = [
	"НЕОНОВА ШАУРМА\n24/7", "КІБЕР-БОРЩ\nЯК У БАБУСІ", "ВАРЕНИКИ 2077", "СИНТ-КАВА\nДЛЯ ДЕДЛАЙНІВ",
	"ОБЕРЕЖНО:\nГУСИ", "ЧЕРГА? НЕМАЄ\nЧЕРГИ", "МАРШРУТ № 13\nВЖЕ ВИРУШАЄ", "ТРАКТОРИ\nНА ПРОКАТ",
	"КАПІБАРА-СПА\nСПОКІЙ І ВАННА", "КОТИ — РІДИНА\nДОВЕДЕНО", "КРЕДИТ\nЗА 5 ХВ*", "ПЕРЕКУС\nНА ОРБІТІ",
]

## Фізичний шар бар'єрів (5-й, «barriers»): машини перевіряють його своїм контуром.
const BARRIER_LAYER: int = 1 << 4
const PSX_SHADER: Shader = preload("res://resources/shaders/psx.gdshader")
const BUILDING_SHADER: Shader = preload("res://resources/shaders/psx_building.gdshader")
const NEON_COLORS: Array[Color] = [
	Color(1.0, 0.2, 0.75), Color(0.15, 0.9, 1.0), Color(1.0, 0.85, 0.2),
	Color(0.6, 0.3, 1.0), Color(1.0, 0.35, 0.25),
]

## Місця для білбордів на фасадах (для вуличних мап): {transform, side, max_height}.
var _facade_spots: Array[Dictionary] = []
var curve: Curve3D
var length: float
## Відстань від початку кривої до лінії фінішу (для кола — уся довжина).
var finish_offset: float
## Номер чекпоінта, проїзд якого завершує коло: 0 (лінія старту) для кола, останній — для спринту.
var finish_checkpoint: int = 0
## Як повертати перетин смуг уздовж кривої — так само, як дорога (Road), щоб відбійники лягали рівно.
var _strip_rotation: CSGPolygon3D.PathRotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW

@onready var path: Path3D = $TrackPath


func _ready() -> void:
	curve = path.curve
	length = curve.get_baked_length()
	if closed:
		start_offset = 0.0
		finish_offset = length
	else:
		finish_offset = length - finish_runout
		finish_checkpoint = checkpoint_count - 1
	var road := get_node_or_null(^"Road") as CSGPolygon3D
	if road:
		_strip_rotation = road.path_rotation
	_build_checkpoints()
	if frontage_buildings:
		_spawn_frontage()
	_spawn_city()
	if elevated and pillar_spacing > 0.0:
		_spawn_pillars()
	if lamp_spacing > 0.0:
		_spawn_lamps()
	if barrier_mode == BarrierMode.FULL:
		_spawn_full_barriers()
	else:
		_spawn_barriers()
	if arch_spacing > 0.0:
		_spawn_arches()
	if billboard_spacing > 0.0:
		_spawn_billboards()
	var traffic: Node3D = load("res://scripts/race/sky_traffic.gd").new()
	traffic.name = "SkyTraffic"
	add_child(traffic)
	# Особливі місця конкретної мапи (тунель, площа тощо) — дочірні вузли з методом build_features.
	# Викликаємо тут, а не в їхньому _ready: тоді крива траси ще не готова.
	for child: Node in get_children():
		if child.has_method(&"build_features"):
			child.build_features(self)


## Точка на центрі дороги через `offset` метрів від старту, повернута за ходом руху.
## `lateral` зсуває вбік (+ праворуч), `height` — вгору.
## На спринті offset обмежується початком і кінцем кривої (за ними траса не продовжується).
func get_transform_at(offset: float, lateral: float = 0.0, height: float = 0.0) -> Transform3D:
	offset = wrap_offset(offset)
	var pos := path.to_global(curve.sample_baked(offset, true))
	var dir: Vector3
	if closed or offset + 2.0 <= length:
		dir = path.to_global(curve.sample_baked(wrap_offset(offset + 2.0), true)) - pos
	else:
		dir = pos - path.to_global(curve.sample_baked(offset - 2.0, true))
	dir.y = 0.0
	var heading := atan2(-dir.x, -dir.z)
	var basis := Basis(Vector3.UP, heading)
	return Transform3D(basis, pos + basis.x * lateral + Vector3.UP * height)


## Відстань уздовж траси до найближчої до `world_pos` точки.
func get_offset_of(world_pos: Vector3) -> float:
	return curve.get_closest_offset(path.to_local(world_pos))


## Offset у межах траси: для кола — по колу, для спринту — між початком і кінцем.
func wrap_offset(offset: float) -> float:
	return fposmod(offset, length) if closed else clampf(offset, 0.0, length)


## На скільки метрів уздовж траси `to` попереду `from` (від'ємне — позаду).
## На колі береться коротший шлях (не більше півкола), на спринті — пряма різниця.
func signed_gap(from: float, to: float) -> float:
	if not closed:
		return to - from
	var d := fposmod(to - from, length)
	return d if d <= length * 0.5 else d - length


## Чи вилетіла машина за межі дороги (далеко вбік або сильно нижче дороги).
func is_off_road(world_pos: Vector3) -> bool:
	var t := get_transform_at(get_offset_of(world_pos))
	var local := world_pos - t.origin
	return absf(local.dot(t.basis.x)) > road_width * 0.5 + 2.5 or local.y < -6.0


## Номер поверху для точки (1 — перший). Лише для трас із floor_height > 0.
func get_floor(world_pos: Vector3) -> int:
	if floor_height <= 0.0:
		return 0
	return maxi(floori((world_pos.y - floor_base_y) / floor_height + 0.01) + 1, 1)


func get_checkpoint_offset(index: int) -> float:
	if closed:
		return index * length / checkpoint_count
	# Спринт: від лінії старту (0) до лінії фінішу (останній) рівними відрізками.
	return start_offset + index * (finish_offset - start_offset) / (checkpoint_count - 1)


func get_checkpoint_transform(index: int) -> Transform3D:
	return get_transform_at(get_checkpoint_offset(index))


func _build_checkpoints() -> void:
	var holder := Node3D.new()
	holder.name = "Checkpoints"
	add_child(holder)
	for i: int in checkpoint_count:
		var area := Area3D.new()
		area.name = "Checkpoint%d" % i
		area.collision_layer = 4      # шар «checkpoints»
		area.collision_mask = 2       # бачить шар «cars»
		area.monitorable = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Лінії старту й фінішу ширші, щоб їх не можна було об'їхати.
		var width := road_width * (3.0 if i == 0 or i == finish_checkpoint else 1.6)
		box.size = Vector3(width, 10.0, 4.0)
		shape.shape = box
		area.add_child(shape)
		holder.add_child(area)
		area.global_transform = get_transform_at(get_checkpoint_offset(i), 0.0, 3.0)
		area.body_entered.connect(_on_checkpoint_body_entered.bind(i))


func _on_checkpoint_body_entered(body: Node3D, index: int) -> void:
	var car := body.get_parent() as Car
	if car:
		checkpoint_passed.emit(car, index)


func _spawn_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed
	var box := BoxMesh.new()
	var building_mat := ShaderMaterial.new()
	building_mat.shader = BUILDING_SHADER
	var sign_mats: Array[ShaderMaterial] = []
	for color: Color in NEON_COLORS:
		sign_mats.append(_psx_material(color * 0.3, color, 2.5, false))

	var holder := Node3D.new()
	holder.name = "City"
	add_child(holder)
	var placed := 0
	var attempts := 0
	while placed < building_count and attempts < building_count * 30:
		attempts += 1
		var size := Vector3(rng.randf_range(10.0, 28.0), 0.0, rng.randf_range(10.0, 28.0))
		var pos := city_area.position + Vector3(
			rng.randf() * city_area.size.x, 0.0, rng.randf() * city_area.size.z)
		var free_radius := road_width * 0.5 + street_margin + maxf(size.x, size.z) * 0.71
		if _distance_to_road(pos) < free_radius or _in_keep_clear(pos, maxf(size.x, size.z) * 0.71):
			continue
		# Що далі від траси, то вищі будинки — виходить «стіна» міста на горизонті.
		var far := clampf((_distance_to_road(pos) - free_radius) / 120.0, 0.0, 1.0)
		# Висота рахується від землі міста (вона на city_floor_y під трасою).
		if elevated:
			size.y = -city_floor_y + rng.randf_range(-15.0, 30.0) + far * rng.randf_range(20.0, 110.0)
		else:
			size.y = rng.randf_range(14.0, 45.0) + far * rng.randf_range(20.0, 90.0)
		pos.y = city_floor_y
		var building := MeshInstance3D.new()
		building.mesh = box
		building.material_override = building_mat
		building.scale = size
		building.position = pos + Vector3.UP * size.y * 0.5
		holder.add_child(building)
		if rng.randf() < 0.35:
			_add_sign(holder, pos, size, sign_mats[rng.randi() % sign_mats.size()], rng)
		placed += 1


## Неонова вивіска на одній зі стін будинку.
func _add_sign(holder: Node3D, base: Vector3, size: Vector3, mat: ShaderMaterial, rng: RandomNumberGenerator) -> void:
	var sign := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var vertical := rng.randf() < 0.6
	var face := rng.randi() % 4
	var along_x := face < 2
	var width := rng.randf_range(1.5, 3.0) if vertical else rng.randf_range(6.0, 12.0)
	var height := rng.randf_range(6.0, 16.0) if vertical else rng.randf_range(1.5, 3.0)
	height = minf(height, size.y * 0.6)
	mesh.size = Vector3(width if along_x else 0.4, height, 0.4 if along_x else width)
	sign.mesh = mesh
	sign.material_override = mat
	var side := 1.0 if face % 2 == 0 else -1.0
	var offset := Vector3(0.0, 0.0, side * (size.z * 0.5 + 0.8)) if along_x \
		else Vector3(side * (size.x * 0.5 + 0.8), 0.0, 0.0)
	sign.position = base + offset + Vector3.UP * rng.randf_range(height * 0.5 + 4.0, maxf(size.y - height * 0.5, height * 0.5 + 4.0))
	holder.add_child(sign)


## Ліхтарі вздовж дороги з обох боків.
func _spawn_lamps() -> void:
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.25, 8.0, 0.25)
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(2.4, 0.2, 0.25)
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(1.4, 0.18, 0.5)
	var pole_mat := _psx_material(Color(0.12, 0.12, 0.14))
	var head_mat := _psx_material(Color(0.8, 0.95, 1.0), Color(0.75, 0.9, 1.0), 3.0)
	head_mat.set_shader_parameter(&"detail_strength", 0.0)
	# Світловий конус від ліхтаря до дороги — як світло в смозі.
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.45
	beam_mesh.bottom_radius = 3.6
	beam_mesh.height = 7.6
	beam_mesh.radial_segments = 10
	beam_mesh.rings = 1
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = preload("res://resources/shaders/light_beam.gdshader")
	beam_mat.set_shader_parameter(&"color", Color(0.7, 0.88, 1.0))
	beam_mat.set_shader_parameter(&"intensity", 0.16)
	beam_mat.set_shader_parameter(&"falloff", 0.9)

	var holder := Node3D.new()
	holder.name = "Lamps"
	add_child(holder)
	var count := int(length / lamp_spacing)
	for i: int in count:
		var offset := (i + 0.5) * length / count
		for side: float in [-1.0, 1.0]:
			var t := get_transform_at(offset, side * (road_width * 0.5 + 0.3))
			var lamp := Node3D.new()
			lamp.transform = t
			var pole := MeshInstance3D.new()
			pole.mesh = pole_mesh
			pole.material_override = pole_mat
			pole.position = Vector3(0.0, 4.0, 0.0)
			var arm := MeshInstance3D.new()
			arm.mesh = arm_mesh
			arm.material_override = pole_mat
			arm.position = Vector3(-side * 1.1, 7.9, 0.0)
			# Ліхтарі стоять на краю естакади; без колізії, щоб не ловити машини.
			var head := MeshInstance3D.new()
			head.mesh = head_mesh
			head.material_override = head_mat
			head.position = Vector3(-side * 2.0, 7.75, 0.0)
			lamp.add_child(pole)
			lamp.add_child(arm)
			lamp.add_child(head)
			var beam := MeshInstance3D.new()
			beam.mesh = beam_mesh
			beam.material_override = beam_mat
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beam.position = Vector3(-side * 2.0, 7.75 - 3.8, 0.0)
			lamp.add_child(beam)
			holder.add_child(lamp)


## Радіус повороту траси в точці offset (м) і його напрямок: +1 — ліворуч, -1 — праворуч.
func _turn_at(offset: float) -> Vector2:
	var a := -get_transform_at(offset).basis.z
	var b := -get_transform_at(offset + 12.0).basis.z
	var angle := a.signed_angle_to(b, Vector3.UP)
	return Vector2(12.0 / maxf(absf(angle), 0.0001), signf(angle))


## Бар'єри з зовнішнього боку крутих поворотів: там машину, що влетіла занадто швидко,
## зупиняє стіна. На пологих поворотах бар'єрів немає — звідти можна вилетіти з естакади.
func _spawn_barriers() -> void:
	# Короткі сегменти: на крутому повороті сусідні мало відрізняються за кутом, тож стіна
	# майже гладка й не «відштовхує» машину, що ковзає вздовж неї.
	var step := 1.5
	# Знаходимо круті ділянки: [початок, кінець, бік повороту].
	var runs: Array[Vector3] = []
	var offset := 0.0
	while offset < length:
		var turn := _turn_at(offset)
		if turn.x < barrier_max_radius:
			var start := offset - barrier_margin
			if not runs.is_empty() and runs[-1].z == turn.y and start - runs[-1].y < 20.0:
				runs[-1].y = offset + 12.0 + barrier_margin
			else:
				runs.append(Vector3(start, offset + 12.0 + barrier_margin, turn.y))
		offset += 2.0

	var holder := Node3D.new()
	holder.name = "Barriers"
	add_child(holder)
	var block := BoxMesh.new()
	block.size = Vector3(0.45, 0.95, step)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.47, 0.14, step)
	var concrete := _psx_material(Color(0.32, 0.31, 0.34))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 1.4, step + 0.1)
	for run: Vector3 in runs:
		# Зовнішній бік: поворот ліворуч (+1) — стіна праворуч (+lateral), і навпаки.
		var side := run.z
		var neon := NEON_COLORS[1] if side < 0.0 else NEON_COLORS[0]
		var neon_mat := _psx_material(neon * 0.4, neon, 2.4, false)
		neon_mat.set_shader_parameter(&"detail_strength", 0.0)
		var white_mat := _psx_material(Color(0.8, 0.8, 0.85), Color(0.9, 0.9, 1.0), 1.2, false)
		white_mat.set_shader_parameter(&"detail_strength", 0.0)
		var wall := StaticBody3D.new()
		wall.name = "Barrier"
		wall.collision_layer = BARRIER_LAYER
		wall.collision_mask = 0
		wall.add_to_group(&"barrier")
		holder.add_child(wall)
		var count := int((run.y - run.x) / step)
		for i: int in count:
			var t := get_transform_at(run.x + (i + 0.5) * step, side * (road_width * 0.5 + 0.25))
			var segment := Node3D.new()
			segment.transform = t
			wall.add_child(segment)
			_add_mesh(segment, block, concrete, Vector3(0.0, 0.47, 0.0))
			# Смуги-«зебра»: неон і біле по черзі, щоб поворот читався здалеку.
			_add_mesh(segment, stripe, neon_mat if i % 2 == 0 else white_mat, Vector3(0.0, 0.78, 0.0))
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.transform = t.translated_local(Vector3(0.0, 0.7, 0.0))
			wall.add_child(collider)


## Будинки-фасади вздовж обох боків траси: «каньйон» вулиці.
func _spawn_frontage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed + 11
	var box := BoxMesh.new()
	var building_mat := ShaderMaterial.new()
	building_mat.shader = BUILDING_SHADER
	var sign_mats: Array[ShaderMaterial] = []
	for color: Color in NEON_COLORS:
		sign_mats.append(_psx_material(color * 0.3, color, 2.5, false))
	var holder := Node3D.new()
	holder.name = "Frontage"
	add_child(holder)
	var edge := road_width * 0.5 + sidewalk_width
	for side: float in [-1.0, 1.0]:
		var offset := 0.0
		while offset < length:
			var width := rng.randf_range(12.0, 24.0)
			var depth := rng.randf_range(12.0, 22.0)
			var t := get_transform_at(offset + width * 0.5, side * (edge + depth * 0.5))
			offset += width + rng.randf_range(0.0, 4.0)
			var pos := t.origin
			# Не на дорозі (крутий поворот) і не на площах.
			if _distance_to_road(pos) < edge + minf(width, depth) * 0.5 - 0.5 or _in_keep_clear(pos, maxf(width, depth) * 0.6):
				continue
			var corners_ok := true
			for cx: float in [-0.5, 0.5]:
				for cz: float in [-0.5, 0.5]:
					var corner := t * Vector3(cx * depth, 0.0, cz * width)
					if _distance_to_road(corner) < edge - 0.5:
						corners_ok = false
			if not corners_ok:
				continue
			var size := Vector3(depth, rng.randf_range(16.0, 55.0), width)
			# Широкий фасад — місце для білборда (рамка 11,8 м), щоб він не стирчав за межі будинку.
			if width >= 14.0 and size.y >= 20.0:
				_facade_spots.append({
					# Точка на 0,6 м перед фасадом (з боку дороги), на рівні землі.
					"transform": Transform3D(t.basis, pos - t.basis.x * side * (depth * 0.5 + 0.6)),
					"side": side,
					"max_height": size.y - 4.0,
				})
			var building := MeshInstance3D.new()
			building.mesh = box
			building.material_override = building_mat
			building.transform = Transform3D(t.basis.scaled(size), pos + Vector3.UP * (size.y * 0.5 - 0.05))
			holder.add_child(building)
			if rng.randf() < 0.45:
				_add_sign(holder, Vector3(pos.x, 0.0, pos.z), Vector3(minf(width, depth), size.y, minf(width, depth)), sign_mats[rng.randi() % sign_mats.size()], rng)


func _in_keep_clear(pos: Vector3, radius: float) -> bool:
	for area: Vector3 in keep_clear:
		if Vector2(pos.x - area.x, pos.z - area.y).length() < area.z + radius:
			return true
	return false


## Суцільні відбійники з обох боків уздовж усієї траси (режим FULL).
## Видима стіна — неперервна CSG-смуга вздовж кривої (гладка на поворотах),
## зіткнення — короткі коробки-сегменти, як і в режимі SHARP_CORNERS (див. Car._check_barriers).
func _spawn_full_barriers() -> void:
	var holder := Node3D.new()
	holder.name = "Barriers"
	add_child(holder)
	var concrete := _psx_material(Color(0.32, 0.31, 0.34))
	var inner := road_width * 0.5
	for side: float in [-1.0, 1.0]:
		var neon := NEON_COLORS[1] if side < 0.0 else NEON_COLORS[0]
		var neon_mat := _psx_material(neon * 0.4, neon, 2.4, false)
		neon_mat.set_shader_parameter(&"detail_strength", 0.0)
		var a := inner * side
		var b := (inner + 0.45) * side
		_add_path_strip(holder, PackedVector2Array([Vector2(a, 0.95), Vector2(b, 0.95), Vector2(b, -0.3), Vector2(a, -0.3)]), concrete)
		_add_path_strip(holder, PackedVector2Array([Vector2(a - 0.02 * side, 0.85), Vector2(b + 0.02 * side, 0.85), Vector2(b + 0.02 * side, 0.7), Vector2(a - 0.02 * side, 0.7)]), neon_mat)
		var wall := StaticBody3D.new()
		wall.name = "Barrier"
		wall.collision_layer = BARRIER_LAYER
		wall.collision_mask = 0
		wall.add_to_group(&"barrier")
		holder.add_child(wall)
		var offset := 0.0
		while offset < length:
			# На поворотах сегменти коротші — стіна майже гладка.
			var step := 1.5 if _turn_at(offset).x < 80.0 else 3.0
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.6, 1.4, step + 0.1)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.transform = get_transform_at(offset + step * 0.5, side * (inner + 0.25), 0.7)
			wall.add_child(collider)
			offset += step


## Смуга заданого перерізу (x — убік від центру, y — висота) уздовж усієї кривої траси.
func _add_path_strip(parent: Node3D, profile: PackedVector2Array, material: Material) -> CSGPolygon3D:
	var strip := CSGPolygon3D.new()
	strip.polygon = profile
	strip.mode = CSGPolygon3D.MODE_PATH
	parent.add_child(strip)
	strip.path_node = strip.get_path_to(path)
	strip.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	strip.path_interval = 1.5
	strip.path_simplify_angle = 0.0
	strip.path_rotation = _strip_rotation
	strip.path_local = false
	strip.path_continuous_u = true
	strip.path_u_distance = 4.0
	strip.path_joined = closed
	strip.material = material
	return strip


## Опори під естакадою — від низу дороги до землі міста.
func _spawn_pillars() -> void:
	var mesh := BoxMesh.new()
	var mat := _psx_material(Color(0.13, 0.13, 0.15))
	var holder := Node3D.new()
	holder.name = "Pillars"
	add_child(holder)
	var count := int(length / pillar_spacing)
	for i: int in count:
		var t := get_transform_at(i * length / count)
		var top := t.origin.y - 6.0   # низ плити дороги
		var pillar := MeshInstance3D.new()
		pillar.mesh = mesh
		pillar.material_override = mat
		pillar.transform = t
		pillar.scale = Vector3(4.0, top - city_floor_y, 3.0)
		pillar.position = Vector3(t.origin.x, (top + city_floor_y) * 0.5, t.origin.z)
		holder.add_child(pillar)


## Неонові арки над трасою — відчуття швидкості. Біля старту не ставимо (там своя арка).
func _spawn_arches() -> void:
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.5, 8.5, 0.5)
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(19.0, 0.35, 0.5)
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.12, 8.0, 0.55)
	var metal := _psx_material(Color(0.35, 0.35, 0.4))
	metal.set_shader_parameter(&"albedo_texture", load("res://assets/textures/metal_panel.png"))
	var neon: Array[ShaderMaterial] = [
		_psx_material(Color(0.1, 0.5, 0.6), Color(0.15, 0.9, 1.0), 3.0),
		_psx_material(Color(0.5, 0.05, 0.35), Color(1.0, 0.15, 0.7), 3.0)]
	var holder := Node3D.new()
	holder.name = "Arches"
	add_child(holder)
	var count := int(length / arch_spacing)
	for i: int in count:
		var offset := (i + 0.5) * length / count
		if offset < 40.0 or offset > length - 40.0:
			continue
		var arch := Node3D.new()
		arch.transform = get_transform_at(offset)
		var glow := neon[i % 2]
		for side: float in [-1.0, 1.0]:
			_add_mesh(arch, post_mesh, metal, Vector3(side * 9.5, 4.25, 0))
			_add_mesh(arch, strip_mesh, glow, Vector3(side * 9.2, 4.2, 0))
		_add_mesh(arch, beam_mesh, glow, Vector3(0, 8.4, 0))
		holder.add_child(arch)


## Рекламні білборди обабіч траси, повернуті до гонщиків.
func _spawn_billboards() -> void:
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(11.0, 4.6, 0.4)
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(11.8, 5.4, 0.2)
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.6, 1.0, 0.6)
	var panel_mat := _psx_material(Color(0.03, 0.02, 0.06), Color(0.06, 0.02, 0.1), 1.0, false)
	var pole_mat := _psx_material(Color(0.12, 0.12, 0.14), Color.BLACK, 0.0, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = city_seed + 5
	var holder := Node3D.new()
	holder.name = "Billboards"
	add_child(holder)
	var count := int(length / billboard_spacing)
	# На вуличних мапах білборди висять на фасадах будинків (обличчям до вулиці, без опори):
	# окремо стоячий білборд застрягав би наполовину в будинках.
	var on_facades := frontage_buildings and not _facade_spots.is_empty()
	for i: int in count:
		var t: Transform3D
		var side := 1.0 if i % 2 == 0 else -1.0
		if on_facades:
			var spot: Dictionary = _facade_spots[int((i + 0.3) * _facade_spots.size() / count) % _facade_spots.size()]
			side = spot.side
			t = spot.transform
			t.origin.y += minf(10.0 + rng.randf() * 6.0, spot.max_height)
			# Обличчям (+Z) — до дороги, площиною вздовж фасаду.
			t.basis = t.basis.rotated(Vector3.UP, -side * PI * 0.5)
		else:
			var offset := (i + 0.3) * length / count
			t = get_transform_at(offset, side * billboard_lateral, 9.0 + rng.randf() * 6.0)
			# Обличчям (+Z) — назустріч гонщикам і трохи до дороги.
			t.basis = t.basis.rotated(Vector3.UP, side * 0.35)
		if _in_keep_clear(t.origin, 8.0):
			continue
		var board := Node3D.new()
		board.transform = t
		var color := NEON_COLORS[rng.randi() % NEON_COLORS.size()]
		# Шари рознесені: рамка позаду панелі, текст помітно перед нею.
		_add_mesh(board, frame_mesh, _psx_material(color * 0.3, color, 2.0, false), Vector3(0, 0, -0.5))
		_add_mesh(board, panel_mesh, panel_mat, Vector3.ZERO)
		if not on_facades:
			var pole := _add_mesh(board, pole_mesh, pole_mat, Vector3(0, 0, -0.9))
			var pole_height := t.origin.y - city_floor_y
			pole.scale.y = pole_height
			pole.position.y = -pole_height * 0.5
		var label := Label3D.new()
		label.text = ADS[i % ADS.size()]
		label.font_size = 80
		label.pixel_size = 0.015
		label.modulate = color.lightened(0.3)
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.shaded = false
		label.double_sided = false
		# Непрозорий текст (без сортування прозорості) не мерехтить на тлі дощу й неону.
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		label.position = Vector3(0, 0, 0.5)
		label.outline_size = 12
		label.outline_modulate = Color(0.02, 0.0, 0.05)
		board.add_child(label)
		holder.add_child(board)


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node


func _distance_to_road(pos: Vector3) -> float:
	var nearest := path.to_global(curve.get_closest_point(path.to_local(pos)))
	return Vector2(pos.x - nearest.x, pos.z - nearest.z).length()


## snap = false вимикає PS1-«тремтіння» вершин — для тексту й тонких неонових деталей,
## які інакше блимають, перекриваючи сусідні шари.
func _psx_material(albedo: Color, emission: Color = Color.BLACK, energy: float = 0.0, snap: bool = true) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PSX_SHADER
	mat.set_shader_parameter(&"albedo", albedo)
	mat.set_shader_parameter(&"emission", emission)
	mat.set_shader_parameter(&"emission_energy", energy)
	if not snap:
		mat.set_shader_parameter(&"snap_grid", Vector2.ZERO)
	return mat
