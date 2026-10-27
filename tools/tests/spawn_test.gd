extends SceneTree
## Кількість ботів: при bot_count 6 / 3 / 1 у гонці має бути 7 / 4 / 2 машини, гонщики без повторів.
func _initialize() -> void:
	var game = root.get_node("Game")
	for n in [6, 3, 1]:
		game.bot_count = n
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		for i in 120: await physics_frame
		var names := []
		for c in main._cars: names.append(c.racer.id)
		var uniq := {}
		for x in names: uniq[x] = true
		print("bot_count=%d cars=%d unique=%d track=%s total_label=%s racers=%s" % [n, main._cars.size(), uniq.size(), main.get_node("TestTrack").scene_file_path, main.get_node("UI/TopLeft/VBox/PlaceRow/PlaceOf").text, names])
		main.queue_free()
		await process_frame
		await process_frame
	quit()
