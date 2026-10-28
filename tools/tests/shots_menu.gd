extends SceneTree
## Скріншоти меню: екран гонщика, екран траси (кожна траса), фокус на «БОТИ» і на кнопках.
func _snap(n: String) -> void:
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + n + ".png")
func _key(menu: Node, action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	menu._input(e)
func _initialize() -> void:
	var menu: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 150: await process_frame
	await _snap("menu_main")
	menu.call("_show_racer_screen")
	await _snap("sel_racer")
	_key(menu, &"ui_accept")
	for i in 60: await process_frame
	await _snap("sel_map_0")
	var game = root.get_node("Game")
	for m in range(1, game.MAPS.size()):
		_key(menu, &"ui_down")
		for i in 90: await process_frame
		await _snap("sel_map_%d" % m)
	_key(menu, &"ui_down")
	_key(menu, &"ui_left")
	_key(menu, &"ui_left")
	await _snap("sel_bots")
	_key(menu, &"ui_down")
	await _snap("sel_buttons")
	print("racer=", game.selected_racer.id, " map=", game.selected_map.id, " bot_count=", game.bot_count)
	quit()
