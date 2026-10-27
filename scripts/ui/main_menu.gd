extends Node3D
## Головне меню і вибір гонщика та налаштувань гонки (траса, кількість ботів).
## На фоні — траса з нічним містом: у головному меню камера повільно облітає старт,
## на екрані вибору — модель гонщика обертається на подіумі.

const RACE_SCENE: String = "res://scenes/main.tscn"
const PSX_SHADER: Shader = preload("res://resources/shaders/psx.gdshader")
const STAT_NAMES: Array[String] = ["Швидкість", "Розгін", "Керування", "Вага"]

enum Screen { MAIN, SELECT }
## Рядки екрана вибору, між якими ходить фокус (↑/↓). Порядок — зверху вниз на екрані.
enum Row { RACER, MAP, BOTS, BUTTONS }

@onready var _camera: Camera3D = $Camera3D
@onready var _turntable: Node3D = $Showcase/Turntable
@onready var _showcase: Node3D = $Showcase
@onready var _main_panel: Control = $UI/MainPanel
@onready var _select_panel: Control = $UI/SelectPanel
@onready var _race_button: Button = $UI/MainPanel/Buttons/RaceButton
@onready var _quit_button: Button = $UI/MainPanel/Buttons/QuitButton
@onready var _start_button: Button = $UI/SelectPanel/Bottom/StartButton
@onready var _back_button: Button = $UI/SelectPanel/Bottom/BackButton
@onready var _prev_button: Button = $UI/SelectPanel/Prev
@onready var _next_button: Button = $UI/SelectPanel/Next
@onready var _name_label: Label = $UI/SelectPanel/Info/VBox/Name
@onready var _bio_label: Label = $UI/SelectPanel/Info/VBox/Bio
@onready var _stat_names_label: Label = $UI/SelectPanel/Info/VBox/StatsRow/StatNames
@onready var _stats_label: Label = $UI/SelectPanel/Info/VBox/StatsRow/Stats
@onready var _skills_label: Label = $UI/SelectPanel/Info/VBox/Skills
@onready var _counter_label: Label = $UI/SelectPanel/Counter
@onready var _map_row: PanelContainer = $UI/SelectPanel/Settings/MapRow
@onready var _map_prev: Button = $UI/SelectPanel/Settings/MapRow/HBox/Prev
@onready var _map_next: Button = $UI/SelectPanel/Settings/MapRow/HBox/Next
@onready var _map_name: Label = $UI/SelectPanel/Settings/MapRow/HBox/Value/Name
@onready var _map_desc: Label = $UI/SelectPanel/Settings/MapRow/HBox/Value/Sub
@onready var _bots_row: PanelContainer = $UI/SelectPanel/Settings/BotsRow
@onready var _bots_prev: Button = $UI/SelectPanel/Settings/BotsRow/HBox/Prev
@onready var _bots_next: Button = $UI/SelectPanel/Settings/BotsRow/HBox/Next
@onready var _bots_value: Label = $UI/SelectPanel/Settings/BotsRow/HBox/Value/Name
@onready var _bots_desc: Label = $UI/SelectPanel/Settings/BotsRow/HBox/Value/Sub

var _screen: Screen = Screen.MAIN
var _index: int = 0
var _map_index: int = 0
var _row: Row = Row.RACER
var _time: float = 0.0
var _model: Node3D


## Фон меню — траса обраної мапи (ставиться до входу сцени в дерево, як і в гонці).
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		Game.swap_in_selected_map($TestTrack)


func _ready() -> void:
	get_tree().paused = false
	_index = maxi(Game.RACERS.find(Game.selected_racer), 0)
	_race_button.pressed.connect(_show_select)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	# У браузері «Вихід» не має сенсу.
	_quit_button.visible = not OS.has_feature("web")
	_start_button.pressed.connect(_start_race)
	_back_button.pressed.connect(_show_main)
	_map_index = maxi(Game.MAPS.find(Game.selected_map), 0)
	_prev_button.pressed.connect(_on_arrow.bind(Row.RACER, -1))
	_next_button.pressed.connect(_on_arrow.bind(Row.RACER, 1))
	_map_prev.pressed.connect(_on_arrow.bind(Row.MAP, -1))
	_map_next.pressed.connect(_on_arrow.bind(Row.MAP, 1))
	_bots_prev.pressed.connect(_on_arrow.bind(Row.BOTS, -1))
	_bots_next.pressed.connect(_on_arrow.bind(Row.BOTS, 1))
	# Клік по самому рядку теж переводить на нього фокус.
	_map_row.gui_input.connect(_on_row_gui_input.bind(Row.MAP))
	_bots_row.gui_input.connect(_on_row_gui_input.bind(Row.BOTS))
	for button: Button in [_race_button, _quit_button, _start_button, _back_button]:
		button.focus_entered.connect(Audio.play.bind(&"ui_move", -6.0))
		button.pressed.connect(Audio.play.bind(&"ui_select", -3.0))
	for button: Button in [_start_button, _back_button]:
		button.focus_entered.connect(_on_bottom_button_focused)
	_show_map()
	_show_bots()
	_show_main()


func _process(delta: float) -> void:
	_time += delta
	if _screen == Screen.MAIN:
		# Повільний обліт стартової арки.
		var angle := 0.6 + _time * 0.1
		var center := Vector3(0.0, 4.0, -60.0)
		var from := center + Vector3(sin(angle) * 34.0, 9.0 + sin(_time * 0.3) * 2.0, cos(angle) * 34.0)
		_camera.look_at_from_position(from, center)
	else:
		_turntable.rotation.y += delta * 0.6


## Екран вибору керуємо тут (а не в _unhandled_input), щоб стрілки не перехоплювала
## стандартна навігація фокусу між кнопками: ↑/↓ — рядок, ←/→ — значення рядка.
## На рядку кнопок ←/→ і Enter лишаємо кнопкам (НАЗАД / СТАРТ).
func _input(event: InputEvent) -> void:
	if _screen != Screen.SELECT:
		return
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"accelerate"):
		_focus_row(wrapi(_row - 1, 0, Row.size()))
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"brake"):
		_focus_row(wrapi(_row + 1, 0, Row.size()))
	elif event.is_action_pressed(&"ui_cancel"):
		_show_main()
	elif _row == Row.BUTTONS:
		return
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"steer_left"):
		_change_row_value(_row, -1)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"steer_right"):
		_change_row_value(_row, 1)
	elif event.is_action_pressed(&"ui_accept"):
		Audio.play(&"ui_select", -3.0)
		_start_race()
	else:
		return
	get_viewport().set_input_as_handled()


func _show_main() -> void:
	_screen = Screen.MAIN
	_main_panel.visible = true
	_select_panel.visible = false
	_showcase.visible = false
	_race_button.grab_focus()


func _show_select() -> void:
	_screen = Screen.SELECT
	_main_panel.visible = false
	_select_panel.visible = true
	_showcase.visible = true
	_show_racer()
	_show_map()
	_show_bots()
	_focus_row(Row.RACER, false)


## Переводить фокус на рядок і підсвічує його. Рядок кнопок — це звичайний фокус на «СТАРТ».
func _focus_row(row: int, with_sound: bool = true) -> void:
	_row = row as Row
	if _row == Row.BUTTONS:
		if not (_start_button.has_focus() or _back_button.has_focus()):
			_start_button.grab_focus()   # звук дає сама кнопка (focus_entered)
	else:
		get_viewport().gui_release_focus()
		if with_sound:
			Audio.play(&"ui_move", -6.0)
	_update_row_highlight()


func _on_bottom_button_focused() -> void:
	_row = Row.BUTTONS
	_update_row_highlight()


func _on_row_gui_input(event: InputEvent, row: Row) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _row != row:
		_focus_row(row)


## Клік мишею по ◀ / ▶: фокус на цей рядок і зміна значення.
func _on_arrow(row: Row, step: int) -> void:
	if _row != row:
		_focus_row(row, false)
	_change_row_value(row, step)


func _change_row_value(row: Row, step: int) -> void:
	match row:
		Row.RACER:
			_change_racer(step)
		Row.MAP:
			_change_map(step)
		Row.BOTS:
			_change_bots(step)


func _change_racer(step: int) -> void:
	Audio.play(&"ui_move", -4.0)
	_index = wrapi(_index + step, 0, Game.RACERS.size())
	_show_racer()


## Наступна / попередня мапа (по колу). Поки мапа одна — нічого не змінюється.
func _change_map(step: int) -> void:
	if Game.MAPS.size() < 2:
		return
	Audio.play(&"ui_move", -4.0)
	_map_index = wrapi(_map_index + step, 0, Game.MAPS.size())
	Game.selected_map = Game.MAPS[_map_index]
	_show_map()
	# Фон меню — теж обрана траса.
	Game.swap_in_selected_map($TestTrack)


## Більше / менше ботів у межах Game.MIN_BOTS..Game.max_bots (без переходу по колу).
func _change_bots(step: int) -> void:
	var before := Game.bot_count
	Game.bot_count = before + step
	if Game.bot_count == before:
		return
	Audio.play(&"ui_move", -4.0)
	_show_bots()


func _show_map() -> void:
	var map: MapData = Game.MAPS[_map_index]
	_map_name.text = map.display_name
	_map_desc.text = map.description
	# Одна мапа — стрілки тьмяні, але сам елемент той самий, що й для багатьох мап.
	var can_switch := Game.MAPS.size() > 1
	for arrow: Button in [_map_prev, _map_next]:
		arrow.modulate.a = 1.0 if can_switch else 0.3
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_switch else Control.CURSOR_ARROW


func _show_bots() -> void:
	var count := Game.bot_count
	_bots_value.text = str(count)
	_bots_desc.text = "%d %s на старті" % [count + 1, _cars_word(count + 1)]
	_bots_prev.modulate.a = 1.0 if count > Game.MIN_BOTS else 0.3
	_bots_next.modulate.a = 1.0 if count < Game.max_bots else 0.3


## Підсвітка рядка у фокусі: неонова рамка (як у готового скіла) для рядків налаштувань,
## світні стрілки біля моделі — для рядка гонщика.
func _update_row_highlight() -> void:
	_map_row.theme_type_variation = &"SkillReady" if _row == Row.MAP else &"SkillIdle"
	_bots_row.theme_type_variation = &"SkillReady" if _row == Row.BOTS else &"SkillIdle"
	var racer_focused := _row == Row.RACER
	for arrow: Button in [_prev_button, _next_button]:
		if racer_focused:
			arrow.add_theme_stylebox_override(&"normal", arrow.get_theme_stylebox(&"focus"))
		else:
			arrow.remove_theme_stylebox_override(&"normal")
	_counter_label.add_theme_color_override(&"font_color",
		Color(1, 0.3, 0.8) if racer_focused else Color(0.3, 0.95, 1))


## «машина / машини / машин» для числа.
static func _cars_word(n: int) -> String:
	var last_two := n % 100
	var last := n % 10
	if last_two >= 11 and last_two <= 14:
		return "машин"
	if last == 1:
		return "машина"
	if last >= 2 and last <= 4:
		return "машини"
	return "машин"


func _show_racer() -> void:
	var racer: RacerData = Game.RACERS[_index]
	if _model:
		_model.queue_free()
	_model = racer.model_scene.instantiate() if racer.model_scene else null
	if _model:
		_paint(_model, racer.car_color)
		_turntable.add_child(_model)
	_turntable.rotation.y = -0.6
	# Камера ближче до малих гонщиків і далі від великих.
	var distance := 3.5 + racer.footprint.y * 1.1
	var target := _showcase.global_position + Vector3(0.0, 0.9, 0.0)
	var from := target + Vector3(-0.55, 0.35, -1.0).normalized() * distance
	_camera.look_at_from_position(from, target)
	# Зсуваємо погляд праворуч, щоб модель була зліва, а інфо-панель — справа.
	_camera.look_at_from_position(from, target + (_camera.global_basis.x * distance * 0.32))

	_counter_label.text = "%d / %d" % [_index + 1, Game.RACERS.size()]
	_name_label.text = racer.display_name
	_bio_label.text = racer.bio
	var stats: Array[int] = [racer.speed, racer.acceleration, racer.handling, racer.weight]
	var bars: PackedStringArray = []
	for value: int in stats:
		bars.append("■".repeat(value) + "□".repeat(3 - value))
	_stat_names_label.text = "\n".join(STAT_NAMES)
	_stats_label.text = "\n".join(bars)
	_skills_label.text = "[Q] %s\n%s\n\n[E] %s (ультімейт)\n%s" % [
		racer.skill_q_name, racer.skill_q_description,
		racer.skill_e_name, racer.skill_e_description]


func _paint(model: Node3D, color: Color) -> void:
	var paint := ShaderMaterial.new()
	paint.shader = PSX_SHADER
	paint.set_shader_parameter(&"albedo", color.darkened(0.25))
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if node.is_in_group(&"paint"):
			(node as MeshInstance3D).material_override = paint


func _start_race() -> void:
	Game.selected_racer = Game.RACERS[_index]
	get_tree().change_scene_to_file(RACE_SCENE)
