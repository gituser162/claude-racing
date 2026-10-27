extends SceneTree
## Скріншоти ключових місць «Спіралі»: старт на даху, заїзд на спіраль, спуск, фініш, вежа збоку.
var OUT := OS.get_environment("OUT") + "/"
func _initialize() -> void:
	var game = root.get_node("Game")
	game.selected_map = game.get_map(&"spiral")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT + "p_grid.png")
	for i in 60 * 4: await physics_frame
	var tr = main.get_node("TestTrack")
	var car = main.get_node("Car")
	car.controlled_by_player = false
	for d in main._drivers.values(): d.active = false
	var cam: Camera3D = main.get_node("ChaseCamera")
	var spots := {"dropin": 40.0, "ramp1": 200.0, "ramp_mid": 800.0, "ramp_low": 1450.0, "finish": tr.finish_offset - 25.0}
	for name in spots:
		car.teleport(tr.get_transform_at(spots[name], 2.0))
		cam.snap()
		for i in 12: await physics_frame
		await process_frame
		root.get_texture().get_image().save_png(OUT + "p_" + name + ".png")
	# Вежа згори-збоку.
	var side := Camera3D.new()
	main.add_child(side)
	side.far = 3000.0
	side.make_current()
	for view in [["p_tower_top", Vector3(120, 45, 140), Vector3(0, -40, 8)]]:
		side.look_at_from_position(view[1], view[2])
		for i in 5: await process_frame
		root.get_texture().get_image().save_png(OUT + view[0] + ".png")
	quit()
