extends SceneTree
## Скріншоти музики: головне меню (ТРЕКИ, рядок «зараз грає»), екран «ТРЕКИ», плашка на старті гонки, пауза.
func _snap(n: String) -> void:
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + n + ".png")
func _key(node: Node, action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	node._input(e)
func _initialize() -> void:
	var audio = root.get_node("Audio")
	var menu: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 150: await process_frame
	await _snap("mus_main")
	menu.call("_show_tracks_screen")
	menu.call("_focus_track_row", 0, false)
	_key(menu, &"ui_down")
	_key(menu, &"ui_down")
	_key(menu, &"ui_accept")     # вимкнути трек
	_key(menu, &"ui_down")
	_key(menu, &"ui_right")      # грати зараз
	await _snap("mus_tracks")
	audio.set_track_enabled(menu._track_row - 1, true)
	menu.queue_free()
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5: await process_frame
	await _snap("mus_race_toast")
	main.get_node("UI/Pause")._open()
	await _snap("mus_pause")
	quit()
