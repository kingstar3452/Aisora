extends SceneTree
## Repeatable developer benchmark. No authentication/network; uncapped render samples.
var options: Dictionary = {}
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	call_deferred("run")
func summary(samples: Array[float]) -> Dictionary:
	samples.sort()
	var total: float = 0.0
	for value: float in samples: total += value
	return {"mean_ms": total / samples.size(), "p50_ms": samples[samples.size() / 2], "p95_ms": samples[mini(samples.size() - 1, int(samples.size() * 0.95))]}
func run() -> void:
	var mode: String = str(options.get("mode", "cpu"))
	var idle: bool = str(options.get("state","talking")) == "idle"
	var app: Node = load("res://scenes/companion.tscn").instantiate()
	app.settings_path = "user://benchmark-no-preferences-%d.cfg" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_process(false)
	app.bridge.set_process(false)
	app.character.set_process(false)
	app.park.set_process(false)
	app.ui_layer.visible = false
	app.character.motion = load("res://scripts/motion_layers.gd").new(2026)
	app.character.rng.seed = 2026
	app.character.set_state(0 if idle else 3)
	app.character.low_power = false
	if options.has("quality"):
		app.quality = int(options.quality)
		app._apply_quality()
		app._apply_performance_settings()
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(960, 600))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 600)
	var result: Dictionary = {"label": str(options.get("label", "sample")), "mode": mode, "engine": Engine.get_version_info().string, "rendering_method": RenderingServer.get_current_rendering_method(), "resolution": "960x600", "quality": app.quality}
	result.state = "idle" if idle else "talking"
	if mode == "cpu":
		for i in 300: app.character.tick(1.0 / 30.0)
		var samples: Array[float] = []
		for batch in 40:
			var start: int = Time.get_ticks_usec()
			for i in 100:
				app.character.mouth = 0.0 if idle else 0.25 + sin(i * 0.15) * 0.20
				app.character.tick(1.0 / 30.0)
			samples.append(float(Time.get_ticks_usec() - start) / 100000.0)
		result.character_tick = summary(samples)
		result.note = "CPU tick microbenchmark; no per-tick render flush, 40 batches of 100 after 300 warmup ticks."
	else:
		var part: String = str(options.get("part", "full"))
		if part == "park": app.character.visible = false
		if part == "character": app.park.visible = false
		var samples: Array[float] = []
		var frames: int = int(options.get("frames", "120"))
		for i in 60 + frames:
			var start: int = Time.get_ticks_usec()
			if part != "park":
				app.character.mouth = 0.0 if idle else 0.25 + sin(i * 0.15) * 0.20
				app.character.tick(1.0 / 30.0)
			if part != "character": app.park._process(1.0 / 30.0)
			await process_frame
			await RenderingServer.frame_post_draw
			if i >= 60: samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
		result.frame = summary(samples)
		result.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		result.primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		result.video_memory_bytes = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		result.process_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		result.part = part
		result.note = "Uncapped wall frame intervals after 60 warmup frames, UI/network disabled. Software renderer if llvmpipe."
	result.static_memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	DirAccess.make_dir_recursive_absolute("res://.local")
	var file: FileAccess = FileAccess.open("res://.local/bench-%s-%s.json" % [result.label, mode], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("AISORA_BENCH ", JSON.stringify(result))
	app.queue_free()
	await process_frame
	quit()
