extends SceneTree
## Скріншоти «під біт»: та сама сцена без спалаху (beat_pulse 0) і на сильному біті (1) — на кожній мапі.
var OUT := OS.get_environment("OUT") + "/"
func _initialize() -> void:
	var game = root.get_node("Game")
	var audio = root.get_node("Audio")
	for map_id in [&"neon_overpass", &"city_street", &"spiral"]:
		game.selected_map = game.get_map(map_id)
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		for i in 60 * 5: await physics_frame
		var tr = main.get_node("TestTrack")
		main.get_node("Car").teleport(tr.get_transform_at(tr.start_offset + 120.0))
		main.get_node("ChaseCamera").snap()
		for i in 10: await physics_frame
		for pulse in [0.0, 1.0]:
			# Audio на час знімка не оновлює пульс — ставимо його напряму.
			audio.set_process(false)
			RenderingServer.global_shader_parameter_set(&"beat_pulse", pulse)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(OUT + "beat_%s_%d.png" % [map_id, int(pulse)])
		audio.set_process(true)
		main.queue_free()
		await process_frame
	quit()
