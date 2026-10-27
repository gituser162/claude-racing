extends SceneTree
## Різні гонщики в заносі влітають у стіну шпильки задом. Міряємо «відкидання» — наскільки
## центр машини відходить від стіни за 0,6 с після удару, найбільший зсув за кадр і втрату швидкості.
func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var track = main.get_node("TestTrack")
	for i in 60 * 4: await physics_frame
	for d in main._drivers.values(): d.active = false
	main.get_node("Car").controlled_by_player = false
	var cars: Array = []
	for id in [&"office", &"courier", &"marshrutka"]:
		for c in main._cars:
			if c.racer.id == id: cars.append(c)
	for c in main._cars:
		c.teleport(track.get_transform_at(100.0 + main._cars.find(c) * 25.0))
	for car in cars:
		for yaw in [150.0, 180.0, -150.0]:
			var t: Transform3D = track.get_transform_at(680.0)
			var dir: Vector3 = (-t.basis.z).rotated(Vector3.UP, deg_to_rad(20.0))
			car.teleport(Transform3D(Basis.looking_at(dir.rotated(Vector3.UP, deg_to_rad(yaw)), Vector3.UP), t.origin + t.basis.x * -2.0))
			for i in 2: await physics_frame
			car.ball.linear_velocity = dir * 34.0
			car._drift = 1.0
			var hit := -1
			var lat_at_hit := 0.0
			var max_away := 0.0
			var max_step := 0.0
			var prev_lat := 0.0
			var v_min := 999.0
			for i in 70:
				car.throttle_input = 1.0
				car.steer_input = 0.0
				await physics_frame
				var off: float = track.get_offset_of(car.body.global_position)
				var tt: Transform3D = track.get_transform_at(off)
				# Відстань від стіни (стіна ліворуч): чим більше lat, тим далі від стіни.
				var lat: float = (car.body.global_position - tt.origin).dot(tt.basis.x)
				if car._scraping and hit < 0:
					hit = i
					lat_at_hit = lat
					prev_lat = lat
				if hit >= 0 and i <= hit + 36:
					max_away = maxf(max_away, lat - lat_at_hit)
					max_step = maxf(max_step, lat - prev_lat)
					v_min = minf(v_min, car.ball.linear_velocity.length() * 3.6)
					prev_lat = lat
			print("%-10s yaw %+d: thrown %.2f m from wall in 0.6 s, max %.2f m/frame, speed min %d km/h" % [car.racer.id, yaw, max_away, max_step, v_min])
	quit()
