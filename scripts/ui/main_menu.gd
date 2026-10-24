extends Node3D
## Головне меню і вибір гонщика. На фоні — траса з нічним містом:
## у головному меню камера повільно облітає старт, на екрані вибору —
## модель гонщика обертається на подіумі.

const RACE_SCENE: String = "res://scenes/main.tscn"
const PSX_SHADER: Shader = preload("res://resources/shaders/psx.gdshader")
const STAT_NAMES: Array[String] = ["Швидкість", "Розгін", "Керування", "Вага"]

enum Screen { MAIN, SELECT }

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

var _screen: Screen = Screen.MAIN
var _index: int = 0
var _time: float = 0.0
var _model: Node3D


func _ready() -> void:
	get_tree().paused = false
	_index = maxi(Game.RACERS.find(Game.selected_racer), 0)
	_race_button.pressed.connect(_show_select)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	# У браузері «Вихід» не має сенсу.
	_quit_button.visible = not OS.has_feature("web")
	_start_button.pressed.connect(_start_race)
	_back_button.pressed.connect(_show_main)
	_prev_button.pressed.connect(_change_racer.bind(-1))
	_next_button.pressed.connect(_change_racer.bind(1))
	for button: Button in [_race_button, _quit_button, _start_button, _back_button]:
		button.focus_entered.connect(Audio.play.bind(&"ui_move", -6.0))
		button.pressed.connect(Audio.play.bind(&"ui_select", -3.0))
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


func _unhandled_input(event: InputEvent) -> void:
	if _screen != Screen.SELECT:
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"steer_left"):
		_change_racer(-1)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"steer_right"):
		_change_racer(1)
	elif event.is_action_pressed(&"ui_cancel"):
		_show_main()
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
	_start_button.grab_focus()


func _change_racer(step: int) -> void:
	Audio.play(&"ui_move", -4.0)
	_index = wrapi(_index + step, 0, Game.RACERS.size())
	_show_racer()


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
