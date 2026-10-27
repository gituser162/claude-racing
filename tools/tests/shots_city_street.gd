extends SceneTree
var OUT := OS.get_environment("OUT") + "/"
func _initialize() -> void:
	var game = root.get_node("Game")
	game.selected_map = game.get_map(&"city_street")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60 * 4: await physics_frame
	var tr = main.get_node("TestTrack")
	var car = main.get_node("Car")
	car.controlled_by_player = false
	for d in main._drivers.values(): d.active = false
	var cam: Camera3D = main.get_node("ChaseCamera")
	var spots := {"start": 4.0, "tunnel": tr.get_offset_of(Vector3(225, 0, -31.25)), "market": tr.get_offset_of(Vector3(205, 0, -231.25)), "plaza": tr.get_offset_of(Vector3(187.5, 0, -270)), "esses": tr.get_offset_of(Vector3(10, 0, -85))}
	for name in spots:
		car.teleport(tr.get_transform_at(spots[name]))
		cam.snap()
		for i in 12: await physics_frame
		await process_frame
		root.get_texture().get_image().save_png(OUT + "s_" + name + ".png")
	# Вид згори.
	var top := Camera3D.new()
	main.add_child(top)
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 470.0
	top.far = 2000.0
	top.global_position = Vector3(131, 600, -112)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.make_current()
	for i in 5: await process_frame
	root.get_texture().get_image().save_png(OUT + "s_top.png")
	quit()
