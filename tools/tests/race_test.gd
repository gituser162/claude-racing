extends SceneTree
## Повна гонка (3 кола): гравця теж веде автопілот (BotDriver, skill 0.95). Друкує час, найкраще коло,
## респауни, «поштовхи» (jolted) і час тертя об бар'єри для кожної машини. Мапа — env MAP (id), за замовч. перша.
var falls := {}
var walls := {}
var scrape := {}
func _initialize() -> void:
	var game = root.get_node("Game")
	if OS.get_environment("MAP") != "":
		game.selected_map = game.get_map(StringName(OS.get_environment("MAP")))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player = main.get_node("Car")
	var d = load("res://scripts/race/bot_driver.gd").new()
	player.add_child(d)
	var rng := RandomNumberGenerator.new()
	d.setup(player, main.get_node("TestTrack"), main._cars, rng)
	d.skill = 0.95
	main._drivers[player] = d
	for c in main._cars:
		falls[c] = 0
		c.respawned.connect(func(): falls[c] += 1)
		walls[c] = 0
		scrape[c] = 0
		c.jolted.connect(func(_s): walls[c] += 1)
	var t := 0
	while t < 60 * 240:
		await physics_frame
		t += 1
		for c in main._cars:
			if c._scraping: scrape[c] += 1
		if t % (60 * 20) == 0:
			print("t=%ds player place %d lap %d" % [t / 60, main._current_order().find(player) + 1, main._states[player].lap])
		if main._finish_order.size() == main._cars.size():
			break
	print("--- results")
	for c in main._finish_order:
		var s = main._states[c]
		print("%s  %.2f  best %.2f  respawns %d  jolts %d  wall %.1fs  %s" % [c.name, s.finish_time, s.best_lap, falls[c], walls[c], scrape[c] / 60.0, c.racer.id])
	for c in main._cars:
		if not main._states[c].finished:
			print("DNF %s lap %d respawns %d" % [c.name, main._states[c].lap, falls[c]])
	quit()
