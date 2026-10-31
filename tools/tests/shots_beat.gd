extends SceneTree
## Скріншоти «під музику» на кожній мапі: тиша (усе вимкнено) і сильна перша доля —
## спалах неону, будинки-«еквалайзери» (смуги спектра задано вручну) і світлова хвиля (0,35 с після старту).
## Плюс вигляд збоку на місто, щоб було видно хвилю й еквалайзери на хмарочосах.
var OUT := OS.get_environment("OUT") + "/"
func _set_music(pulse: float, bands_lo: Vector4, bands_hi: Vector4, wave_from: Vector3, wave_t: float, wave_s: float) -> void:
	RenderingServer.global_shader_parameter_set(&"beat_pulse", pulse)
	RenderingServer.global_shader_parameter_set(&"music_bands_lo", bands_lo)
	RenderingServer.global_shader_parameter_set(&"music_bands_hi", bands_hi)
	RenderingServer.global_shader_parameter_set(&"beat_wave", Vector4(wave_from.x, wave_from.y, wave_from.z, wave_t))
	RenderingServer.global_shader_parameter_set(&"beat_wave_strength", wave_s)
func _initialize() -> void:
	var game = root.get_node("Game")
	var audio = root.get_node("Audio")
	for map_id in [&"neon_overpass", &"city_street", &"spiral"]:
		game.selected_map = game.get_map(map_id)
		var main: Node = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		for i in 60 * 5: await physics_frame
		var tr = main.get_node("TestTrack")
		var car = main.get_node("Car")
		car.teleport(tr.get_transform_at(tr.start_offset + 120.0))
		main.get_node("ChaseCamera").snap()
		for i in 10: await physics_frame
		audio.set_process(false)
		var cam_pos: Vector3 = main.get_node("ChaseCamera").global_position
		var lo := Vector4(0.95, 0.8, 0.55, 0.7)
		var hi := Vector4(0.4, 0.6, 0.35, 0.2)
		for shot in [["quiet", 0.0, Vector4.ZERO, Vector4.ZERO, 100.0, 0.0], ["beat", 1.0, lo, hi, 0.35, 1.0]]:
			_set_music(shot[1], shot[2], shot[3], cam_pos, shot[4], shot[5])
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(OUT + "mus_%s_%s.png" % [map_id, shot[0]])
		# Вид на місто збоку-згори.
		var side := Camera3D.new()
		main.add_child(side)
		side.far = 3000.0
		var c: Vector3 = car.body.global_position
		side.look_at_from_position(c + Vector3(0, 70, 140), c + Vector3(0, 0, -80))
		side.make_current()
		# Окремо: лише «еквалайзери» (без хвилі й спалаху) і лише хвиля.
		for view in [["eq", 0.0, lo, hi, 100.0, 0.0], ["wave", 0.0, Vector4.ZERO, Vector4.ZERO, 0.5, 1.0]]:
			_set_music(view[1], view[2], view[3], c, view[4], view[5])
			for i in 3: await process_frame
			root.get_texture().get_image().save_png(OUT + "mus_%s_city_%s.png" % [map_id, view[0]])
		audio.set_process(true)
		main.queue_free()
		await process_frame
	quit()
