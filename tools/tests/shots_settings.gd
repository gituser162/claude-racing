extends SceneTree
## Скріншоти: головне меню (кнопка НАЛАШТУВАННЯ), вікно налаштувань у меню і на паузі.
func _snap(n: String) -> void:
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + n + ".png")
func _initialize() -> void:
	var menu: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 120: await process_frame
	await _snap("set_main")
	menu.get_node("UI/SettingsPanel").open()
	menu.get_node("UI/SettingsPanel")._focus_row(2, false)
	await _snap("set_menu")
	menu.queue_free()
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	var pause = main.get_node("UI/Pause")
	pause._open()
	await _snap("set_pause")
	pause.get_node("SettingsPanel").open()
	await _snap("set_pause_open")
	quit()
