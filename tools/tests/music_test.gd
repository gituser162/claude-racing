extends SceneTree
## Плейлист: усі треки вантажаться, «вперед/назад», вимкнені не грають, останній не вимикається,
## налаштування зберігаються. Відновлює початкові налаштування музики після себе.
func _initialize() -> void:
	await process_frame
	var audio = root.get_node("Audio")
	var ok := true
	for i in audio.track_count():
		var t: Dictionary = audio.get_track(i)
		var stream := load(t.path) as AudioStream
		print("%-28s %-48s %5.0f с  %s" % [t.artist, t.title, stream.get_length() if stream else -1.0, "ok" if stream else "НЕ ВАНТАЖИТЬСЯ"])
		ok = ok and stream != null
	var saved: Array = []
	for i in audio.track_count():
		saved.append(audio.is_track_enabled(i))
	for i in audio.track_count():
		audio.set_track_enabled(i, true)
	# Вперед: за одне «коло» плейлиста — усі треки без повторів.
	audio.play_track(0)
	var seen := {audio.current_track: true}
	for i in audio.track_count() - 1:
		audio.next_track()
		seen[audio.current_track] = true
	print("вперед: різних треків %d з %d" % [seen.size(), audio.track_count()])
	ok = ok and seen.size() == audio.track_count()
	var a: int = audio.current_track
	audio.next_track()
	var b: int = audio.current_track
	audio.prev_track()
	print("назад: %d → %d → назад %d (очікується %d)" % [a, b, audio.current_track, a])
	ok = ok and audio.current_track == a
	# Вимикаємо всі, крім двох.
	for i in range(2, audio.track_count()):
		audio.set_track_enabled(i, false)
	var played := {}
	for i in 10:
		audio.next_track()
		played[audio.current_track] = true
	print("лише 0 і 1 увімкнені → грали: %s" % [played.keys()])
	ok = ok and played.keys().all(func(k): return k < 2)
	audio.set_track_enabled(0, false)
	var last_off: bool = audio.set_track_enabled(1, false)
	print("вимкнути останній: %s (має бути false), увімкнено %d" % [last_off, audio.enabled_count()])
	ok = ok and not last_off and audio.enabled_count() == 1
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	print("збережено вимкнених: %d" % cfg.get_value("music", "disabled", []).size())
	audio.play_track(5)
	print("грати зараз 5: current=%d enabled=%s" % [audio.current_track, audio.is_track_enabled(5)])
	ok = ok and audio.current_track == 5
	for i in audio.track_count():
		audio.set_track_enabled(i, true)
	for i in audio.track_count():
		if not saved[i]:
			audio.set_track_enabled(i, false)
	print("RESULT ", "OK" if ok else "FAIL")
	quit()
