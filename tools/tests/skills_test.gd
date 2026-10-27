extends SceneTree
## Перевірка кожного скіла кожного гонщика: ставимо його між двома суперниками й вмикаємо Q, потім E.
var main
var track
func park(car, offset: float, lateral: float = 0.0, speed: float = 0.0) -> void:
	car.teleport(track.get_transform_at(offset, lateral))
	car.ball.linear_velocity = car.get_forward() * speed
func state(c) -> String:
	return "%s[v=%.0f%s%s%s%s]" % [c.racer.id, c.get_speed() * 3.6, " SLOW" if c.is_slowed() else "", " SPIN" if c.is_spinning() else "", " PROT" if c.is_protected() else "", " GHOST" if c.is_ghost() else ""]
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	track = main.get_node("TestTrack")
	for f in 200: await physics_frame
	for c in main._cars:
		if main._drivers.has(c): main._drivers[c].active = false
		c.controlled_by_player = false
		c.skills.unlock_ultimate()
	var cars: Array = main._cars
	for i in cars.size():
		var user = cars[i]
		var ahead = cars[(i + 1) % cars.size()]
		var behind = cars[(i + 2) % cars.size()]
		for k in cars.size():
			if not cars[k] in [user, ahead, behind]:
				park(cars[k], 700.0 + k * 25.0)
		for which in ["q", "e"]:
			park(user, 40.0, 0.0, 15.0)
			park(ahead, 52.0, 0.5, 15.0)
			park(behind, 32.0, -2.5, 15.0)
			for f in 3: await physics_frame
			var before_user: Vector3 = user.body.global_position
			var ok = user.skills.q.activate() if which == "q" else user.skills.e.activate()
			var rep := "%-10s %s ok=%s" % [user.racer.id, which.to_upper(), ok]
			for f in 50:
				user.throttle_input = 1.0; ahead.throttle_input = 1.0; behind.throttle_input = 1.0
				await physics_frame
				if f == 10:
					rep += "  @10: %s %s %s" % [state(user), state(ahead), state(behind)]
			var moved: float = (user.body.global_position - before_user).length()
			rep += "  user moved %.0f m" % moved
			print(rep)
			user.skills.q.cooldown_left = 0.0
	quit()
