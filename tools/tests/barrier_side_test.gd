extends SceneTree
## Бар'єр: машина в заносі боком у стіну шпильки естакади: кузов повернутий на yaw відносно руху, кермо — у бік повороту.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var track = main.get_node("TestTrack")
	for i in 60 * 4: await physics_frame
	for c in main._cars:
		if c != main.get_node("Car"):
			c.teleport(track.get_transform_at(100.0 + main._cars.find(c) * 20.0))
			main._drivers[c].active = false
	var car = main.get_node("Car")
	car.controlled_by_player = false
	for move_angle in [15.0, 30.0]:
		for yaw in [-40.0, 40.0, -70.0]:
			for steer in [-1.0, 0.0]:
				var t: Transform3D = track.get_transform_at(680.0)
				var dir: Vector3 = (-t.basis.z).rotated(Vector3.UP, deg_to_rad(move_angle))
				var face: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(yaw))
				car.teleport(Transform3D(Basis.looking_at(face, Vector3.UP), t.origin + t.basis.x * -2.5))
				for i in 2: await physics_frame
				car.ball.linear_velocity = dir * 36.0
				car._drift = 1.0
				var hit_frame := -1
				var v_before := 0.0
				var v_min := 999.0
				var max_away := 0.0
				for i in 60:
					car.throttle_input = 1.0
					car.steer_input = steer
					var v0: float = car.ball.linear_velocity.length()
					await physics_frame
					if car._scraping and hit_frame < 0:
						hit_frame = i
						v_before = v0 * 3.6
					if hit_frame >= 0 and i <= hit_frame + 20:
						v_min = minf(v_min, car.ball.linear_velocity.length() * 3.6)
						var off: float = track.get_offset_of(car.body.global_position)
						var tt: Transform3D = track.get_transform_at(off)
						max_away = maxf(max_away, car.ball.linear_velocity.dot(tt.basis.x))
				print("move %d° yaw %+d° steer %+d: before=%d km/h, min after=%d km/h, away=%.1f m/s" % [move_angle, yaw, steer, v_before, v_min, max_away])
	quit()
