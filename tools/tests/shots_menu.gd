extends SceneTree
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
	menu.call("_show_select")
	await _snap("sel_racer")
	_key(menu, &"ui_down")
	await _snap("sel_map")
	_key(menu, &"ui_down")
	_key(menu, &"ui_left")
	_key(menu, &"ui_left")
	await _snap("sel_bots")
	print("bot_count=", root.get_node("Game").bot_count)
	quit()
