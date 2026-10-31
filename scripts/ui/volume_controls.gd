extends VBoxContainer
## Повзунки гучності «Музика» і «Ефекти» та сили світлових ефектів під біт («Пульс»).
## Вузол сам створює рядки й зберігає налаштування через Audio.

func _ready() -> void:
	_add_row("МУЗИКА", Audio.music_level, Audio.set_music_level)
	_add_row("ЕФЕКТИ", Audio.sfx_level, Audio.set_sfx_level)
	_add_row("ПУЛЬС", Audio.beat_visuals, Audio.set_beat_visuals)


func _add_row(title: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"HudLabel"
	label.custom_minimum_size = Vector2(62, 0)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(90, 14)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_change)
	# Короткий звук-підказка, щоб чути гучність ефектів одразу.
	slider.value_changed.connect(func(_v: float) -> void: Audio.play(&"ui_move", -4.0))
	row.add_child(label)
	row.add_child(slider)
	add_child(row)
