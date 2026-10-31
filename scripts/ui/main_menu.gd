extends Node3D
## Головне меню → вибір гонщика → вибір траси й кількості ботів → гонка; з головного меню — «ТРЕКИ» (які пісні грають).
## На фоні — траса обраної мапи з нічним містом: у головному меню камера повільно облітає старт,
## на екрані гонщика модель обертається на подіумі, на екрані траси камера облітає обрану трасу.

const RACE_SCENE: String = "res://scenes/main.tscn"
const PSX_SHADER: Shader = preload("res://resources/shaders/psx.gdshader")
const STAT_NAMES: Array[String] = ["Швидкість", "Розгін", "Керування", "Вага"]

enum Screen { MAIN, RACER, MAP, TRACKS }

@onready var _camera: Camera3D = $Camera3D
@onready var _turntable: Node3D = $Showcase/Turntable
@onready var _showcase: Node3D = $Showcase
@onready var _main_panel: Control = $UI/MainPanel
@onready var _race_button: Button = $UI/MainPanel/Buttons/RaceButton
@onready var _quit_button: Button = $UI/MainPanel/Buttons/QuitButton
@onready var _tracks_button: Button = $UI/MainPanel/Buttons/TracksButton
@onready var _settings_button: Button = $UI/MainPanel/Buttons/SettingsButton
@onready var _settings: Control = $UI/SettingsPanel
# Екран треків.
@onready var _tracks_panel: Control = $UI/TracksPanel
@onready var _tracks_counter: Label = $UI/TracksPanel/Counter
@onready var _tracks_scroll: ScrollContainer = $UI/TracksPanel/Scroll
@onready var _tracks_list: VBoxContainer = $UI/TracksPanel/Scroll/List
@onready var _tracks_all_button: Button = $UI/TracksPanel/Bottom/AllButton
@onready var _tracks_back_button: Button = $UI/TracksPanel/Bottom/BackButton
# Екран гонщика.
@onready var _select_panel: Control = $UI/SelectPanel
@onready var _continue_button: Button = $UI/SelectPanel/Bottom/ContinueButton
@onready var _racer_back_button: Button = $UI/SelectPanel/Bottom/BackButton
@onready var _prev_button: Button = $UI/SelectPanel/Prev
@onready var _next_button: Button = $UI/SelectPanel/Next
@onready var _name_label: Label = $UI/SelectPanel/Info/VBox/Name
@onready var _bio_label: Label = $UI/SelectPanel/Info/VBox/Bio
@onready var _stat_names_label: Label = $UI/SelectPanel/Info/VBox/StatsRow/StatNames
@onready var _stats_label: Label = $UI/SelectPanel/Info/VBox/StatsRow/Stats
@onready var _skills_label: Label = $UI/SelectPanel/Info/VBox/Skills
@onready var _counter_label: Label = $UI/SelectPanel/Counter
# Екран траси.
@onready var _map_panel: Control = $UI/MapPanel
@onready var _map_counter: Label = $UI/MapPanel/Counter
@onready var _map_racer_name: Label = $UI/MapPanel/Racer/VBox/Name
@onready var _map_list: VBoxContainer = $UI/MapPanel/Column/Maps
@onready var _start_button: Button = $UI/MapPanel/Bottom/StartButton
@onready var _map_back_button: Button = $UI/MapPanel/Bottom/BackButton
@onready var _bots_row: PanelContainer = $UI/MapPanel/Column/BotsRow
@onready var _bots_prev: Button = $UI/MapPanel/Column/BotsRow/HBox/Prev
@onready var _bots_next: Button = $UI/MapPanel/Column/BotsRow/HBox/Next
@onready var _bots_value: Label = $UI/MapPanel/Column/BotsRow/HBox/Value/Name
@onready var _bots_desc: Label = $UI/MapPanel/Column/BotsRow/HBox/Value/Sub

var _screen: Screen = Screen.MAIN
var _index: int = 0
var _map_index: int = 0
## Рядок у фокусі на екрані траси: 0..мап-1 — картки трас, далі — «БОТИ», далі — кнопки.
var _map_row: int = 0
## На екрані гонщика: true — фокус на кнопках (НАЗАД / ДАЛІ), false — на виборі гонщика.
var _racer_buttons_focused: bool = false
var _time: float = 0.0
var _model: Node3D
var _map_cards: Array[PanelContainer] = []
## Екран треків: рядки (по одному на трек) і рядок у фокусі (останній + 1 — кнопки).
var _track_rows: Array[PanelContainer] = []
var _track_row: int = 0


## Фон меню — траса обраної мапи (ставиться до входу сцени в дерево, як і в гонці).
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_place_showcase(Game.swap_in_selected_map($TestTrack))


## Подіум з моделлю — у місці, яке задає траса (на «Спіралі» він на даху вежі).
func _place_showcase(track: Node3D) -> void:
	var track_script := track as Track
	if track_script:
		$Showcase.position = track_script.menu_showcase


func _ready() -> void:
	get_tree().paused = false
	_index = maxi(Game.RACERS.find(Game.selected_racer), 0)
	_map_index = maxi(Game.MAPS.find(Game.selected_map), 0)
	_race_button.pressed.connect(_show_racer_screen)
	_tracks_button.pressed.connect(_show_tracks_screen)
	_settings_button.pressed.connect(_settings.open)
	_settings.closed.connect(_settings_button.grab_focus)
	_tracks_back_button.pressed.connect(_show_main)
	_tracks_all_button.pressed.connect(_enable_all_tracks)
	_tracks_all_button.focus_entered.connect(_on_track_buttons_focused)
	_tracks_back_button.focus_entered.connect(_on_track_buttons_focused)
	Audio.track_changed.connect(func(_i: int) -> void: _update_track_rows())
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	# У браузері «Вихід» не має сенсу.
	_quit_button.visible = not OS.has_feature("web")
	_continue_button.pressed.connect(_show_map_screen)
	_racer_back_button.pressed.connect(_show_main)
	_start_button.pressed.connect(_start_race)
	_map_back_button.pressed.connect(_show_racer_screen)
	_prev_button.pressed.connect(_change_racer.bind(-1))
	_next_button.pressed.connect(_change_racer.bind(1))
	_bots_prev.pressed.connect(_on_bots_arrow.bind(-1))
	_bots_next.pressed.connect(_on_bots_arrow.bind(1))
	_bots_row.gui_input.connect(_on_row_click.bind(_bots_row_index))
	for button: Button in [_race_button, _tracks_button, _settings_button, _quit_button, _continue_button, _racer_back_button, _start_button, _map_back_button, _tracks_all_button, _tracks_back_button]:
		button.focus_entered.connect(Audio.play.bind(&"ui_move", -6.0))
		button.pressed.connect(Audio.play.bind(&"ui_select", -3.0))
	_continue_button.focus_entered.connect(_on_racer_buttons_focused)
	_racer_back_button.focus_entered.connect(_on_racer_buttons_focused)
	_start_button.focus_entered.connect(_on_map_buttons_focused)
	_map_back_button.focus_entered.connect(_on_map_buttons_focused)
	_build_map_cards()
	_build_track_rows()
	_show_bots()
	_show_main()


func _process(delta: float) -> void:
	_time += delta
	match _screen:
		Screen.MAIN, Screen.TRACKS:
			# Повільний обліт стартової арки.
			var angle := 0.6 + _time * 0.1
			var center := Vector3(0.0, 4.0, -60.0)
			var from := center + Vector3(sin(angle) * 34.0, 9.0 + sin(_time * 0.3) * 2.0, cos(angle) * 34.0)
			_camera.look_at_from_position(from, center)
		Screen.RACER:
			_turntable.rotation.y += delta * 0.6
		Screen.MAP:
			# Обліт обраної траси: точку й висоту задає сама траса (Track.menu_preview_*).
			var track := $TestTrack as Track
			var center := track.menu_preview_center if track else Vector3(0.0, 0.0, -45.0)
			var radius := track.menu_preview_radius if track else 62.0
			var height := track.menu_preview_height if track else 26.0
			var angle := 0.9 + _time * 0.12
			var from := center + Vector3(sin(angle) * radius, height + sin(_time * 0.25) * 3.0, cos(angle) * radius)
			# Погляд трохи ліворуч від центру — праворуч від списку трас лишається вільне місце для фону.
			_camera.look_at_from_position(from, center)
			_camera.look_at_from_position(from, center - _camera.global_basis.x * 18.0)


## Екрани вибору керуємо тут (а не в _unhandled_input), щоб стрілки не перехоплювала
## стандартна навігація фокусу між кнопками. На рядку кнопок ←/→ і Enter лишаємо кнопкам.
func _input(event: InputEvent) -> void:
	if _settings.visible:
		return   # вікно налаштувань керує собою саме
	match _screen:
		Screen.RACER:
			_input_racer(event)
		Screen.MAP:
			_input_map(event)
		Screen.TRACKS:
			_input_tracks(event)


## Екран треків: ↑/↓ — трек, Enter / пробіл — увімкнути/вимкнути, → — грати зараз, Esc — назад.
func _input_tracks(event: InputEvent) -> void:
	var rows := _track_rows.size() + 1
	if event.is_action_pressed(&"ui_cancel"):
		_show_main()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"accelerate"):
		_focus_track_row(wrapi(_track_row - 1, 0, rows))
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"brake"):
		_focus_track_row(wrapi(_track_row + 1, 0, rows))
	elif _track_row >= _track_rows.size():
		return
	elif event.is_action_pressed(&"ui_accept"):
		_toggle_track(_track_row)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"steer_right"):
		_play_track_now(_track_row)
	else:
		return
	get_viewport().set_input_as_handled()


## Екран гонщика: ←/→ — гонщик, Enter — далі, ↑/↓ — між гонщиком і кнопками.
func _input_racer(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_show_main()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"accelerate") \
			or event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"brake"):
		_focus_racer_buttons(not _racer_buttons_focused)
	elif _racer_buttons_focused:
		return
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"steer_left"):
		_change_racer(-1)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"steer_right"):
		_change_racer(1)
	elif event.is_action_pressed(&"ui_accept"):
		Audio.play(&"ui_select", -3.0)
		get_viewport().set_input_as_handled()
		_show_map_screen()
		return
	else:
		return
	get_viewport().set_input_as_handled()


## Екран траси: ↑/↓ — траси, «БОТИ», кнопки; ←/→ — кількість ботів; Enter — старт.
func _input_map(event: InputEvent) -> void:
	var rows := _bots_row_index() + 2
	if event.is_action_pressed(&"ui_cancel"):
		_show_racer_screen()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"accelerate"):
		_focus_map_row(wrapi(_map_row - 1, 0, rows))
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"brake"):
		_focus_map_row(wrapi(_map_row + 1, 0, rows))
	elif _map_row == _buttons_row_index():
		return
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"steer_left"):
		if _map_row == _bots_row_index():
			_change_bots(-1)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"steer_right"):
		if _map_row == _bots_row_index():
			_change_bots(1)
	elif event.is_action_pressed(&"ui_accept"):
		# Позначаємо натискання обробленим ДО зміни сцени: після неї меню вже не в дереві.
		get_viewport().set_input_as_handled()
		Audio.play(&"ui_select", -3.0)
		_start_race()
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _show_main() -> void:
	var from_tracks := _screen == Screen.TRACKS
	_screen = Screen.MAIN
	_main_panel.visible = true
	_select_panel.visible = false
	_map_panel.visible = false
	_tracks_panel.visible = false
	_showcase.visible = false
	(_tracks_button if from_tracks else _race_button).grab_focus()


func _show_tracks_screen() -> void:
	_screen = Screen.TRACKS
	_main_panel.visible = false
	_tracks_panel.visible = true
	_update_track_rows()
	_focus_track_row(maxi(Audio.current_track, 0), false)


func _show_racer_screen() -> void:
	_screen = Screen.RACER
	_tracks_panel.visible = false
	_main_panel.visible = false
	_select_panel.visible = true
	_map_panel.visible = false
	_showcase.visible = true
	_show_racer()
	_focus_racer_buttons(false, false)


func _show_map_screen() -> void:
	Game.selected_racer = Game.RACERS[_index]
	_screen = Screen.MAP
	_main_panel.visible = false
	_select_panel.visible = false
	_map_panel.visible = true
	_showcase.visible = false
	_time = 0.0
	_map_racer_name.text = Game.selected_racer.display_name
	_show_bots()
	_focus_map_row(_map_index, false)


func _bots_row_index() -> int:
	return Game.MAPS.size()


func _buttons_row_index() -> int:
	return Game.MAPS.size() + 1


func _focus_racer_buttons(on_buttons: bool, with_sound: bool = true) -> void:
	_racer_buttons_focused = on_buttons
	if on_buttons:
		if not (_continue_button.has_focus() or _racer_back_button.has_focus()):
			_continue_button.grab_focus()   # звук дає сама кнопка (focus_entered)
	else:
		get_viewport().gui_release_focus()
		if with_sound:
			Audio.play(&"ui_move", -6.0)
	_update_racer_highlight()


func _on_racer_buttons_focused() -> void:
	_racer_buttons_focused = true
	_update_racer_highlight()


## Світні стрілки біля моделі — коли вибір гонщика у фокусі.
func _update_racer_highlight() -> void:
	for arrow: Button in [_prev_button, _next_button]:
		if not _racer_buttons_focused:
			arrow.add_theme_stylebox_override(&"normal", arrow.get_theme_stylebox(&"focus"))
		else:
			arrow.remove_theme_stylebox_override(&"normal")
	_counter_label.add_theme_color_override(&"font_color",
		Color(1, 0.3, 0.8) if not _racer_buttons_focused else Color(0.3, 0.95, 1))


## Переводить фокус на рядок екрана траси. Рядок картки траси одразу обирає цю трасу.
func _focus_map_row(row: int, with_sound: bool = true) -> void:
	_map_row = row
	if row == _buttons_row_index():
		if not (_start_button.has_focus() or _map_back_button.has_focus()):
			_start_button.grab_focus()   # звук дає сама кнопка (focus_entered)
	else:
		get_viewport().gui_release_focus()
		if row < Game.MAPS.size() and row != _map_index:
			_select_map(row)
		elif with_sound:
			Audio.play(&"ui_move", -6.0)
	_update_map_highlight()


func _on_map_buttons_focused() -> void:
	_map_row = _buttons_row_index()
	_update_map_highlight()


func _on_row_click(event: InputEvent, row_getter: Callable) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var row: int = row_getter.call()
		if _map_row != row:
			_focus_map_row(row)


func _on_map_card_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if click.double_click and index == _map_index:
			_start_race()
		elif _map_row != index:
			_focus_map_row(index)


## Клік мишею по ◀ / ▶ біля ботів: фокус на цей рядок і зміна значення.
func _on_bots_arrow(step: int) -> void:
	if _map_row != _bots_row_index():
		_focus_map_row(_bots_row_index(), false)
	_change_bots(step)


func _change_racer(step: int) -> void:
	Audio.play(&"ui_move", -4.0)
	_index = wrapi(_index + step, 0, Game.RACERS.size())
	_show_racer()


## Обирає трасу: фон меню — теж ця траса; подіум переїжджає туди, де йому місце на ній.
func _select_map(index: int) -> void:
	Audio.play(&"ui_move", -4.0)
	_map_index = index
	Game.selected_map = Game.MAPS[_map_index]
	_place_showcase(Game.swap_in_selected_map($TestTrack))


## Більше / менше ботів у межах Game.MIN_BOTS..Game.max_bots (без переходу по колу).
func _change_bots(step: int) -> void:
	var before := Game.bot_count
	Game.bot_count = before + step
	if Game.bot_count == before:
		return
	Audio.play(&"ui_move", -4.0)
	_show_bots()


## Картки трас: назва, тип (коло / спринт), довжина і опис. Довжину й тип беремо зі сцени траси
## (без додавання в дерево — місто й дорога тоді не будуються, це швидко).
func _build_map_cards() -> void:
	for i: int in Game.MAPS.size():
		var map: MapData = Game.MAPS[i]
		var card := PanelContainer.new()
		card.theme_type_variation = &"SkillIdle"
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", -1)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(box)
		var title := Label.new()
		title.theme_type_variation = &"GlitchLabel"
		title.add_theme_font_size_override(&"font_size", 13)
		title.text = map.display_name
		var info := Label.new()
		info.theme_type_variation = &"HudLabel"
		info.add_theme_font_size_override(&"font_size", 9)
		info.add_theme_color_override(&"font_color", Color(0.3, 0.95, 1))
		info.text = _map_summary(map)
		var desc := Label.new()
		desc.add_theme_font_size_override(&"font_size", 8)
		desc.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.85))
		desc.text = map.description
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		for label: Label in [title, info, desc]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(label)
		card.gui_input.connect(_on_map_card_input.bind(i))
		_map_list.add_child(card)
		_map_cards.append(card)


## «Коло · 3 кола · 1,3 км» або «Спринт · 1 заїзд · 1,5 км».
func _map_summary(map: MapData) -> String:
	var scene := map.load_scene()
	if scene == null:
		return ""
	var track := scene.instantiate() as Track
	if track == null:
		return ""
	var path := track.get_node(^"TrackPath") as Path3D
	var length := path.curve.get_baked_length()
	var closed := track.closed
	var distance := length if closed else length - track.start_offset - track.finish_runout
	track.free()
	var km := ("%.1f км" % (distance / 1000.0)).replace(".", ",")
	var no_skills := "" if map.skills_enabled else " · без умінь"
	if closed:
		return "Коло · %d %s · %s%s" % [map.laps, _laps_word(map.laps), km, no_skills]
	return "Спринт · один заїзд · %s%s" % [km, no_skills]


## Підсвітка: обрана траса — неонова рамка (яскравіша, коли рядок у фокусі), інші — притушені.
func _update_map_highlight() -> void:
	for i: int in _map_cards.size():
		var card := _map_cards[i]
		var selected := i == _map_index
		card.theme_type_variation = &"SkillReady" if selected else &"SkillIdle"
		card.modulate = Color(1, 1, 1, 1) if selected else Color(0.7, 0.68, 0.78, 0.9)
		if selected and _map_row != i:
			card.modulate = Color(0.9, 0.9, 0.95, 1)
		var title := card.get_child(0).get_child(0) as Label
		title.text = ("▶ " if selected else "") + Game.MAPS[i].display_name
		title.add_theme_color_override(&"font_color", Color(1, 0.85, 0.3) if selected else Color(0.85, 0.85, 0.95))
	_bots_row.theme_type_variation = &"SkillReady" if _map_row == _bots_row_index() else &"SkillIdle"
	_map_counter.text = "%d / %d" % [_map_index + 1, Game.MAPS.size()]


func _show_bots() -> void:
	var count := Game.bot_count
	_bots_value.text = str(count)
	_bots_desc.text = "%d %s на старті" % [count + 1, _cars_word(count + 1)]
	_bots_prev.modulate.a = 1.0 if count > Game.MIN_BOTS else 0.3
	_bots_next.modulate.a = 1.0 if count < Game.max_bots else 0.3


## Рядки екрана треків: прапорець ■/□, назва й виконавець, позначка «грає», кнопка ▶ (грати зараз).
func _build_track_rows() -> void:
	for i: int in Audio.track_count():
		var track: Dictionary = Audio.get_track(i)
		var row := PanelContainer.new()
		row.theme_type_variation = &"SkillIdle"
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var box := HBoxContainer.new()
		box.add_theme_constant_override(&"separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var check := Label.new()
		check.add_theme_font_size_override(&"font_size", 12)
		check.custom_minimum_size = Vector2(12, 0)
		check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override(&"separation", -3)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := Label.new()
		title.theme_type_variation = &"GlitchLabel"
		title.add_theme_font_size_override(&"font_size", 11)
		title.text = track.title
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var artist := Label.new()
		artist.add_theme_font_size_override(&"font_size", 8)
		artist.text = track.artist
		artist.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		texts.add_child(title)
		texts.add_child(artist)
		var playing := Label.new()
		playing.theme_type_variation = &"HudLabel"
		playing.add_theme_font_size_override(&"font_size", 8)
		playing.add_theme_color_override(&"font_color", Color(0.3, 0.95, 1))
		playing.text = "♪ ГРАЄ"
		playing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var play := Button.new()
		play.text = "▶"
		play.flat = true
		play.focus_mode = Control.FOCUS_NONE
		play.tooltip_text = "Грати зараз"
		play.custom_minimum_size = Vector2(18, 0)
		play.add_theme_font_size_override(&"font_size", 11)
		play.add_theme_color_override(&"font_color", Color(0.3, 0.95, 1))
		play.add_theme_color_override(&"font_hover_color", Color(1, 0.3, 0.8))
		play.pressed.connect(_play_track_now.bind(i))
		for label: Label in [check, title, artist, playing]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(check)
		box.add_child(texts)
		box.add_child(playing)
		box.add_child(play)
		row.gui_input.connect(_on_track_row_input.bind(i))
		row.set_meta(&"check", check)
		row.set_meta(&"title", title)
		row.set_meta(&"artist", artist)
		row.set_meta(&"playing", playing)
		_tracks_list.add_child(row)
		_track_rows.append(row)


func _on_track_row_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_focus_track_row(index, false)
		_toggle_track(index)


func _focus_track_row(row: int, with_sound: bool = true) -> void:
	_track_row = row
	if row >= _track_rows.size():
		if not (_tracks_all_button.has_focus() or _tracks_back_button.has_focus()):
			_tracks_back_button.grab_focus()   # звук дає сама кнопка (focus_entered)
	else:
		get_viewport().gui_release_focus()
		# Відкладено: одразу після показу екрана розмітка ще не порахована.
		_tracks_scroll.ensure_control_visible.call_deferred(_track_rows[row])
		if with_sound:
			Audio.play(&"ui_move", -6.0)
	_update_track_rows()


func _on_track_buttons_focused() -> void:
	_track_row = _track_rows.size()
	_update_track_rows()


## Увімкнути / вимкнути трек. Останній увімкнений вимкнути не можна — тоді лише «бип» і підказка.
func _toggle_track(index: int) -> void:
	if Audio.set_track_enabled(index, not Audio.is_track_enabled(index)):
		Audio.play(&"ui_select", -4.0)
	else:
		Audio.play(&"hit", -10.0)
		_tracks_counter.text = "хоч один трек має грати"
		return
	_update_track_rows()


func _play_track_now(index: int) -> void:
	Audio.play(&"ui_select", -4.0)
	Audio.play_track(index)
	_update_track_rows()


func _enable_all_tracks() -> void:
	for i: int in Audio.track_count():
		Audio.set_track_enabled(i, true)
	_update_track_rows()


func _update_track_rows() -> void:
	if _track_rows.is_empty():
		return
	for i: int in _track_rows.size():
		var row := _track_rows[i]
		var on := Audio.is_track_enabled(i)
		var focused := _screen == Screen.TRACKS and i == _track_row
		row.theme_type_variation = &"SkillReady" if focused else &"SkillIdle"
		var check := row.get_meta(&"check") as Label
		check.text = "■" if on else "□"
		check.add_theme_color_override(&"font_color", Color(1, 0.3, 0.8) if on else Color(0.5, 0.5, 0.6))
		(row.get_meta(&"title") as Label).add_theme_color_override(&"font_color",
			Color(1, 0.85, 0.3) if on else Color(0.55, 0.55, 0.65))
		(row.get_meta(&"artist") as Label).add_theme_color_override(&"font_color",
			Color(0.85, 0.85, 0.95) if on else Color(0.5, 0.5, 0.6))
		(row.get_meta(&"playing") as Label).visible = i == Audio.current_track
	_tracks_counter.text = "грають %d з %d" % [Audio.enabled_count(), Audio.track_count()]


## «коло / кола / кіл» для числа.
static func _laps_word(n: int) -> String:
	var last_two := n % 100
	var last := n % 10
	if last_two >= 11 and last_two <= 14:
		return "кіл"
	if last == 1:
		return "коло"
	if last >= 2 and last <= 4:
		return "кола"
	return "кіл"


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
