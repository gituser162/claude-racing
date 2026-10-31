extends HBoxContainer
## Рядок «зараз грає» з кнопками ◀ / ▶ (попередній / наступний трек) — для головного меню й паузи.
## Вузол сам створює елементи й оновлюється, коли Audio перемикає трек.

var _label: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", 4)
	var prev := _arrow("◀")
	prev.pressed.connect(Audio.prev_track)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 9)
	_label.add_theme_color_override(&"font_color", Color(1, 0.85, 0.3))
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.custom_minimum_size = Vector2(100, 0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var next := _arrow("▶")
	next.pressed.connect(Audio.next_track)
	add_child(prev)
	add_child(_label)
	add_child(next)
	Audio.track_changed.connect(_update)
	_update(Audio.current_track)


func _update(index: int) -> void:
	var track: Dictionary = Audio.get_track(index)
	_label.text = "♪ —" if track.is_empty() else "♪ %s — %s" % [track.artist, track.title]
	tooltip_text = _label.text


func _arrow(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	# Лише мишею: клавіатурою треки перемикають [ / ], а фокус лишається на кнопках меню.
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(18, 0)
	button.add_theme_font_size_override(&"font_size", 11)
	button.add_theme_color_override(&"font_color", Color(0.3, 0.95, 1))
	button.add_theme_color_override(&"font_hover_color", Color(1, 0.3, 0.8))
	button.pressed.connect(Audio.play.bind(&"ui_move", -6.0))
	return button
