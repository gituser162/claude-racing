extends SceneTree
## Вікно «НАЛАШТУВАННЯ»: відкривається з меню й паузи, ←/→ змінюють значення, усе зберігається
## в один settings.cfg (звук, треки й екран не затирають одне одного), Esc у паузі закриває спершу
## налаштування. Відновлює початкові налаштування після себе.
func _key(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	root.push_input(e)
func _initialize() -> void:
	var audio = root.get_node("Audio")
	var settings = root.get_node("Settings")
	var backup := FileAccess.get_file_as_string("user://settings.cfg")
	var ok := true
	var menu: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 10: await process_frame
	var panel = menu.get_node("UI/SettingsPanel")
	menu._settings_button.emit_signal("pressed")
	await process_frame
	print("відкрилось з меню: ", panel.visible)
	ok = ok and panel.visible
	var music0: float = audio.music_level
	_key(&"ui_left")                      # рядок 0 — музика: −5%
	await process_frame
	print("музика %.2f → %.2f" % [music0, audio.music_level])
	ok = ok and is_equal_approx(audio.music_level, maxf(music0 - 0.05, 0.0))
	# Рядки: 0 музика, 1 ефекти, 2 пульс, 3 еквалайзери (ліва колонка); 4 режим, 5 розмір, 6 FPS, 7 синхр. (права).
	for i in 6:
		_key(&"ui_down")
		await process_frame
	print("рядок після 6×↓: ", panel._row)
	_key(&"ui_left")
	await process_frame
	print("FPS: ", settings.fps_limit, "  Engine.max_fps=", Engine.max_fps)
	ok = ok and settings.fps_limit == 240 and Engine.max_fps == 240
	for i in 4:
		_key(&"ui_up")
		await process_frame
	print("рядок після 4×↑: ", panel._row, " (2 — пульс)")
	var lights0: bool = audio.beat_lights
	_key(&"ui_right")
	await process_frame
	_key(&"ui_down")                       # → Будинки-еквалайзери
	await process_frame
	_key(&"ui_accept")
	await process_frame
	print("пульс %s → %s, еквалайзери → %s" % [lights0, audio.beat_lights, audio.eq_buildings])
	ok = ok and audio.beat_lights != lights0 and not audio.eq_buildings
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	print("у файлі: music=%s fps=%s eq=%s disabled-треки=%s" % [cfg.get_value("audio", "music"), cfg.get_value("display", "fps_limit"), cfg.get_value("visuals", "eq_buildings"), cfg.has_section_key("music", "disabled")])
	ok = ok and cfg.get_value("display", "fps_limit") == 240 and cfg.get_value("visuals", "eq_buildings") == false and cfg.has_section_key("music", "disabled")
	_key(&"ui_cancel")
	await process_frame
	print("Esc закрив: ", not panel.visible, ", фокус на НАЛАШТУВАННЯ: ", menu._settings_button.has_focus())
	ok = ok and not panel.visible
	menu.queue_free()
	await process_frame
	# Пауза в гонці.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	var pause = main.get_node("UI/Pause")
	pause._open()
	await process_frame
	pause._settings_button.emit_signal("pressed")
	await process_frame
	var pp = pause.get_node("SettingsPanel")
	print("з паузи відкрилось: ", pp.visible, ", гра на паузі: ", paused)
	_key(&"ui_cancel")
	await process_frame
	print("Esc: налаштування закриті %s, пауза лишилась %s" % [not pp.visible, pause.visible])
	ok = ok and not pp.visible and pause.visible and paused
	paused = false
	var f := FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	f.store_string(backup)
	f.close()
	print("RESULT ", "OK" if ok else "FAIL")
	quit()
