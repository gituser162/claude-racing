extends SceneTree
## Знімки для порівняння стилю: меню з машиною на подіумі + гонка з автопілотом.
var out: String
func _snap(n: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out + "/" + n + ".png")
func _initialize() -> void:
	out = OS.get_environment("OUT")
	var menu: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	for i in 150: await process_frame
	menu.call("_show_racer_screen")
	for i in 60: await process_frame
	await _snap("menu")
	menu.queue_free()
	await process_frame
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player = main.get_node("Car")
	var d = load("res://scripts/race/bot_driver.gd").new()
	player.add_child(d)
	d.setup(player, main.get_node("TestTrack"), main._cars, RandomNumberGenerator.new())
	d.skill = 0.95
	main._drivers[player] = d
	for i in 60 * 6: await physics_frame
	await _snap("race1")
	for i in 60 * 9: await physics_frame
	await _snap("race2")
	for i in 60 * 10: await physics_frame
	await _snap("race3")
	quit()
