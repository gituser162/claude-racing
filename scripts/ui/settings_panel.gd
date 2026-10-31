extends Control
## Вікно «НАЛАШТУВАННЯ» поверх меню чи паузи: звук, екран, світло під музику.
## Будує себе саме; відкривається open(), закривається Esc / «НАЗАД» (сигнал closed).
## Клавіатура: ↑/↓ — рядок, ←/→ — змінити, Enter — «НАЗАД»; миша — стрілки ◀ ▶ і повзунки.
## Працює й на паузі (process_mode ALWAYS).

signal closed

const THEME: Theme = preload("res://resources/ui/neon_theme.tres")
const CYAN := Color(0.3, 0.95, 1)
const PINK := Color(1, 0.3, 0.8)
const YELLOW := Color(1, 0.85, 0.3)

## Рядки: {kind: "slider"/"choice"/"section", panel, value (Label) або slider, ...}.
var _rows: Array[Dictionary] = []
var _row: int = 0
var _back: Button
var _panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = THEME
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"GlitchLabel"
	title.add_theme_font_size_override(&"font_size", 18)
	title.add_theme_color_override(&"font_color", PINK)
	title.text = "НАЛАШТУВАННЯ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# Дві колонки: ліворуч звук і світло під музику, праворуч екран. Порядок рядків для ↑/↓ —
	# спершу ліва колонка, потім права.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 12)
	box.add_child(columns)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for column: VBoxContainer in [left, right]:
		column.add_theme_constant_override(&"separation", 3)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
	_section(left, "ЗВУК")
	_slider(left, "Музика", func() -> float: return Audio.music_level, Audio.set_music_level)
	_slider(left, "Ефекти", func() -> float: return Audio.sfx_level, Audio.set_sfx_level)
	_section(left, "СВІТЛО ПІД МУЗИКУ")
	_choice(left, "Пульс під біт",
		func() -> String: return "Увімк." if Audio.beat_lights else "Вимк.",
		func(_step: int) -> void: Audio.set_beat_lights(not Audio.beat_lights))
	_choice(left, "Еквалайзери",
		func() -> String: return "Увімк." if Audio.eq_buildings else "Вимк.",
		func(_step: int) -> void: Audio.set_eq_buildings(not Audio.eq_buildings))
	_section(right, "ЕКРАН")
	_choice(right, "Режим",
		func() -> String: return Settings.WINDOW_MODE_NAMES[Settings.window_mode],
		func(step: int) -> void: Settings.set_window_mode(wrapi(Settings.window_mode + step, 0, 3) as Settings.WindowMode))
	_choice(right, "Розмір вікна",
		func() -> String: return Settings.size_name(Settings.window_size) if Settings.window_mode == Settings.WindowMode.WINDOWED else "на весь екран",
		_change_size,
		func() -> bool: return Settings.window_mode == Settings.WindowMode.WINDOWED)
	_choice(right, "Обмеження FPS",
		func() -> String: return Settings.fps_name(Settings.fps_limit),
		func(step: int) -> void:
			var i := maxi(Settings.FPS_LIMITS.find(Settings.fps_limit), 0)
			Settings.set_fps_limit(Settings.FPS_LIMITS[wrapi(i + step, 0, Settings.FPS_LIMITS.size())]))
	_choice(right, "Верт. синхр.",
		func() -> String: return "Увімк." if Settings.vsync else "Вимк.",
		func(_step: int) -> void: Settings.set_vsync(not Settings.vsync))
	var note := Label.new()
	note.add_theme_font_size_override(&"font_size", 8)
	note.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.8))
	note.text = "Пульс — неон і екран спалахують під біт, хвиля світла по вікнах.\nЕквалайзери — будинки з вікнами-стовпчиками під музику."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(250, 0)
	left.add_child(note)

	var hint := Label.new()
	hint.add_theme_font_size_override(&"font_size", 8)
	hint.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.8))
	hint.text = "↑/↓ вибір · ←/→ змінити · Esc назад"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_back = Button.new()
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.custom_minimum_size = Vector2(160, 0)
	_back.text = "НАЗАД"
	_back.focus_entered.connect(func() -> void:
		_row = _rows.size()
		_update())
	_back.pressed.connect(close)
	_back.pressed.connect(Audio.play.bind(&"ui_select", -3.0))
	box.add_child(_back)


func open() -> void:
	visible = true
	_row = 0
	_refresh_values()
	_focus_row(0, false)
	_center.call_deferred()


## По центру екрана (після того, як панель порахувала свій розмір).
func _center() -> void:
	_panel.reset_size()
	_panel.position = ((size - _panel.size) * 0.5).round()


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		Audio.play(&"ui_select", -3.0)
		close()
	elif event.is_action_pressed(&"ui_up"):
		_focus_row(wrapi(_row - 1, 0, _rows.size() + 1))
	elif event.is_action_pressed(&"ui_down"):
		_focus_row(wrapi(_row + 1, 0, _rows.size() + 1))
	elif _row >= _rows.size():
		return   # на кнопці «НАЗАД» Enter обробляє сама кнопка
	elif event.is_action_pressed(&"ui_left"):
		_change(_row, -1)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_accept"):
		_change(_row, 1)
	else:
		return
	get_viewport().set_input_as_handled()


func _focus_row(row: int, with_sound: bool = true) -> void:
	_row = row
	if row >= _rows.size():
		_back.grab_focus()
	else:
		get_viewport().gui_release_focus()
		if with_sound:
			Audio.play(&"ui_move", -6.0)
	_update()


func _change(row: int, step: int) -> void:
	var r: Dictionary = _rows[row]
	if r.has("enabled") and not (r.enabled as Callable).call():
		return
	if r.kind == "slider":
		var slider: HSlider = r.slider
		slider.value = clampf(slider.value + step * 0.05, 0.0, 1.0)   # set_* — через value_changed
	else:
		(r.change as Callable).call(step)
		Audio.play(&"ui_move", -4.0)
	_refresh_values()


func _change_size(step: int) -> void:
	var sizes := Settings.available_sizes()
	var i := maxi(sizes.find(Settings.window_size), 0)
	Settings.set_window_size(sizes[clampi(i + step, 0, sizes.size() - 1)])


func _refresh_values() -> void:
	for r: Dictionary in _rows:
		if r.kind == "slider":
			(r.slider as HSlider).set_value_no_signal((r.get as Callable).call())
			(r.value as Label).text = "%d%%" % roundi((r.slider as HSlider).value * 100.0)
		else:
			(r.value as Label).text = (r.get as Callable).call()
	_update()


func _update() -> void:
	for i: int in _rows.size():
		var r: Dictionary = _rows[i]
		var panel: PanelContainer = r.panel
		panel.theme_type_variation = &"SkillReady" if i == _row else &"SkillIdle"
		var active: bool = not r.has("enabled") or (r.enabled as Callable).call()
		panel.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.45)


func _section(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"HudLabel"
	label.add_theme_font_size_override(&"font_size", 9)
	label.add_theme_color_override(&"font_color", CYAN)
	label.text = text
	box.add_child(label)


func _row_panel(box: VBoxContainer, caption: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SkillIdle"
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override(&"separation", 4)
	panel.add_child(hbox)
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", 10)
	label.text = caption
	label.custom_minimum_size = Vector2(84, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	var index := _rows.size()
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _row != index:
			_focus_row(index))
	box.add_child(panel)
	_rows.append({"panel": panel})
	return hbox


func _slider(box: VBoxContainer, caption: String, getter: Callable, setter: Callable) -> void:
	var hbox := _row_panel(box, caption)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(90, 14)
	var value := Label.new()
	value.add_theme_font_size_override(&"font_size", 10)
	value.add_theme_color_override(&"font_color", YELLOW)
	value.custom_minimum_size = Vector2(34, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		value.text = "%d%%" % roundi(v * 100.0)
		Audio.play(&"ui_move", -4.0))
	hbox.add_child(slider)
	hbox.add_child(value)
	var r := _rows[-1]
	r.kind = "slider"
	r.slider = slider
	r.value = value
	r.get = getter


func _choice(box: VBoxContainer, caption: String, getter: Callable, change: Callable, enabled: Callable = Callable()) -> void:
	var hbox := _row_panel(box, caption)
	var index := _rows.size() - 1
	var prev := _arrow("◀")
	prev.pressed.connect(func() -> void:
		_focus_row(index, false)
		_change(index, -1))
	var value := Label.new()
	value.theme_type_variation = &"GlitchLabel"
	value.add_theme_font_size_override(&"font_size", 11)
	value.add_theme_color_override(&"font_color", YELLOW)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := _arrow("▶")
	next.pressed.connect(func() -> void:
		_focus_row(index, false)
		_change(index, 1))
	hbox.add_child(prev)
	hbox.add_child(value)
	hbox.add_child(next)
	var r := _rows[-1]
	r.kind = "choice"
	r.value = value
	r.get = getter
	r.change = change
	if enabled.is_valid():
		r.enabled = enabled


func _arrow(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(18, 0)
	button.add_theme_font_size_override(&"font_size", 11)
	button.add_theme_color_override(&"font_color", CYAN)
	button.add_theme_color_override(&"font_hover_color", PINK)
	return button
