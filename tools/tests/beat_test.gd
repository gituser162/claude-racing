extends SceneTree
## Біти в реальному часі: 8 с Turbo Killer (~147 BPM) — скільки спалахів і з яким інтервалом.
## Запускати БЕЗ --fixed-fps (потрібен реальний час відтворення).
func _initialize() -> void:
	await process_frame
	var audio = root.get_node("Audio")
	audio.play_track(8)   # Turbo Killer, ~147 BPM
	var hits: Array = []
	audio.beat.connect(func(s): hits.append([Time.get_ticks_msec() / 1000.0, s, audio._music.get_playback_position()]))
	var t0 := Time.get_ticks_msec()
	var maxp := 0.0
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		maxp = maxf(maxp, audio.beat_pulse)
	print("позиція треку %.2f с, бітів %d (очікується ~%d за 8 с при 147 BPM), max pulse %.2f" % [audio._music.get_playback_position(), hits.size(), int(8 * 147 / 60.0), maxp])
	if hits.size() > 3:
		var iv: Array = []
		for i in range(1, hits.size()):
			iv.append(hits[i][0] - hits[i - 1][0])
		iv.sort()
		print("інтервал між спалахами (медіана) %.3f с, очікується %.3f" % [iv[iv.size() / 2], 60.0 / 147.3])
	quit()
