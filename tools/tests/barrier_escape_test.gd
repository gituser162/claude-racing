extends SceneTree
## «Спіраль»: машина треться об зовнішній відбійник (поворот увесь час ліворуч, стіна праворуч)
## і гравець кермує від стіни. Має відірватись від стіни й виїхати до середини дороги.
## Друкує, через скільки секунд машина відійшла від стіни на 1 м і як далеко від стіни відійшла за 1,5 с.
## Очікування: при повному кермі (1.0, 0.7) — відрив за ~0,5 с і кілька метрів; до виправлення — «НІКОЛИ».
func _initialize() -> void:
	var game = root.get_node("Game")
	game.selected_map = game.get_map(&"spiral")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var track = main.get_node("TestTrack")
	for i in 60 * 4: await physics_frame
	var car = main.get_node("Car")
	for c in main._cars:
		if c != car:
			c.teleport(track.get_transform_at(1200.0 + main._cars.find(c) * 25.0))
			main._drivers[c].active = false
	car.controlled_by_player = false
	track.respawn_off_road = false
	for yaw in [0.0, -15.0, 25.0]:          # ніс: уздовж стіни / у стіну / до дороги (занос)
		for steer in [1.0, 0.7]:
			var t: Transform3D = track.get_transform_at(400.0)
			var face: Vector3 = (-t.basis.z).rotated(Vector3.UP, deg_to_rad(yaw))
			car.teleport(Transform3D(Basis.looking_at(face, Vector3.UP), t.origin + t.basis.x * 5.6))
			for i in 2: await physics_frame
			car.ball.linear_velocity = -t.basis.z * 36.0 + t.basis.x * 2.0
			car._drift = 1.0 if yaw > 0.0 else 0.0
			var away_time := -1.0
			var lateral := 0.0
			var min_lateral := 99.0
			var scrape := 0
			for i in 90:
				car.throttle_input = 1.0
				car.steer_input = steer
				await physics_frame
				var off: float = track.get_offset_of(car.body.global_position)
				var tt: Transform3D = track.get_transform_at(off)
				lateral = (car.body.global_position - tt.origin).dot(tt.basis.x)
				if car._scraping: scrape += 1
				if i < 90: min_lateral = minf(min_lateral, lateral)
				if away_time < 0.0 and lateral < 7.0 - car.footprint.x * 0.5 - 1.0:
					away_time = i / 60.0
			print("yaw %+3d° steer %.1f: від стіни на 1 м за %s, за 1,5 с відійшов до lateral %.1f м (стіна 7), %d км/год" % [yaw, steer, ("%.2f с" % away_time) if away_time >= 0.0 else "НІКОЛИ", min_lateral, car.ball.linear_velocity.length() * 3.6])
	quit()
