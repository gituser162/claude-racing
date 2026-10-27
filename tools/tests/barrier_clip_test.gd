extends SceneTree
## Бар'єр: чи заходить кузов у стіну (16 точок по контуру) при ударах під різними кутами. Очікується 0.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var track = main.get_node("TestTrack")
	var space = main.get_world_3d().direct_space_state
	for i in 60 * 4: await physics_frame
	for d in main._drivers.values(): d.active = false
	main.get_node("Car").controlled_by_player = false
	var cars := []
	for c in main._cars:
		c.teleport(track.get_transform_at(100.0 + main._cars.find(c) * 25.0))
		if c.racer.id in [&"office", &"marshrutka"]: cars.append(c)
	var total := 0
	var inside_frames := 0
	for car in cars:
		for yaw in [-150.0, -60.0, 0.0, 60.0, 150.0]:
			for move in [10.0, 35.0]:
				var t: Transform3D = track.get_transform_at(680.0)
				var dir: Vector3 = (-t.basis.z).rotated(Vector3.UP, deg_to_rad(move))
				car.teleport(Transform3D(Basis.looking_at(dir.rotated(Vector3.UP, deg_to_rad(yaw)), Vector3.UP), t.origin + t.basis.x * -2.0))
				for i in 2: await physics_frame
				car.ball.linear_velocity = dir * 34.0
				car._drift = 1.0 if absf(yaw) > 0.0 else 0.0
				for i in 50:
					car.throttle_input = 1.0
					car.steer_input = 0.0
					await physics_frame
					total += 1
					var f: Vector3 = car.get_forward()
					var r := Vector3(-f.z, 0, f.x)
					var inside := false
					for sx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
						for sz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
							if absf(sx) < 1.0 and absf(sz) < 1.0: continue
							var q := PhysicsPointQueryParameters3D.new()
							q.position = car.ball.global_position + Vector3.UP * 0.2 + r * sx * (car.footprint.x * 0.5 - 0.06) + f * sz * (car.footprint.y * 0.5 - 0.06)
							q.collision_mask = 16
							if space.intersect_point(q, 1).size() > 0: inside = true
					if inside: inside_frames += 1
	print("frames with body inside wall: %d / %d" % [inside_frames, total])
	quit()
