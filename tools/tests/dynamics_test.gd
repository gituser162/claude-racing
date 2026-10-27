extends SceneTree
## Динаміка гонки: автопілот гравця (skill з env SKILL, напр. 0.85 / 0.95 / 1.0), мапа — env MAP: міряємо, наскільки щільно машини біля гравця
## і скільки разів змінювалось місце гравця. Друкує результати.
func _initialize() -> void:
	var skill := float(OS.get_environment("SKILL"))
	var game = root.get_node("Game")
	if OS.get_environment("MAP") != "":
		game.selected_map = game.get_map(StringName(OS.get_environment("MAP")))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player = main.get_node("Car")
	var d = load("res://scripts/race/bot_driver.gd").new()
	player.add_child(d)
	d.setup(player, main.get_node("TestTrack"), main._cars, RandomNumberGenerator.new())
	d.skill = skill
	main._drivers[player] = d
	var samples := 0
	var near_sum := 0.0
	var spread_sum := 0.0
	var place_changes := 0
	var last_place := -1
	var t := 0
	while t < 60 * 260:
		await physics_frame
		t += 1
		if main._states[player].finished: break
		if t % 30 == 0 and t > 60 * 5:
			var pp: float = main._progress(player)
			var near := 0
			var lo := 1e9
			var hi := -1e9
			for c in main._cars:
				var p: float = main._progress(c)
				lo = minf(lo, p)
				hi = maxf(hi, p)
				if c != player and absf(p - pp) < 35.0: near += 1
			near_sum += near
			spread_sum += hi - lo
			samples += 1
			var place: int = main._current_order().find(player)
			if last_place >= 0 and place != last_place: place_changes += 1
			last_place = place
	var order = main._current_order()
	print("skill=%.2f  finish place=%d/%d  avg bots within 35m of player=%.1f  avg field spread=%d m  player place changes=%d" % [skill, order.find(player) + 1, order.size(), near_sum / maxf(samples, 1), spread_sum / maxf(samples, 1), place_changes])
	quit()
