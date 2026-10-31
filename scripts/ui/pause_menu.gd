extends Control
## Пауза під час гонки (Esc / Start). Працює й тоді, коли гра на паузі.

const MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"

@onready var _continue_button: Button = $Panel/VBox/ContinueButton
@onready var _restart_button: Button = $Panel/VBox/RestartButton
@onready var _menu_button: Button = $Panel/VBox/MenuButton
@onready var _settings_button: Button = $Panel/VBox/SettingsButton
@onready var _settings: Control = $SettingsPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for button: Button in [_continue_button, _restart_button, _settings_button, _menu_button]:
		button.focus_entered.connect(Audio.play.bind(&"ui_move", -6.0))
		button.pressed.connect(Audio.play.bind(&"ui_select", -3.0))
	_continue_button.pressed.connect(_resume)
	_settings_button.pressed.connect(_settings.open)
	_settings.closed.connect(_settings_button.grab_focus)
	_restart_button.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	_menu_button.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible:
		return
	if event.is_action_pressed(&"pause"):
		if visible:
			_resume()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()


func _open() -> void:
	get_tree().paused = true
	visible = true
	_continue_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	visible = false
