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
	var coordinator: bool=str(options.get("coordinator","false"))=="true"
	var app: Node = load("res://scenes/companion.tscn").instantiate()
	app.settings_path = "user://benchmark-no-preferences-%d.cfg" % Time.get_ticks_usec()
	# Fix the scene before _ready: do not benchmark an incidental local-clock fade.
	var config: ConfigFile = ConfigFile.new()
	config.set_value("world", "override", "sunset")
	config.set_value("world", "displayed_slot", "sunset")
	config.save(app.settings_path)
	root.add_child(app)
	app.set_process(false)
	app.bridge.set_process(false)
	app.character.set_process(false)
	app.park.set_process(false)
	app.ui_layer.visible = false
	app.character.motion = load("res://scripts/motion_layers.gd").new(2026)
	app.character.rng.seed = 2026
	app.character.set_state(0 if idle else 3)
	if coordinator:
		app.manual_state=-1
		app.bridge.state={"voice":"inactive" if idle else "active","capturing":not idle,"rms":0.,"connected":true,"pending":false,"error":""}
		app.bridge.session_may_be_active=not idle
	app.character.low_power = false
	var action: String=str(options.get("action", ""))
	if not action.is_empty():
		app.character.ground.calibrated=true
		app.character.ground.width=2.5;app.character.ground.depth=2.5
		app.character.body.enabled=true
		app.character.motion.scheduler_enabled=false
		if action in app.character.body.ACTIONS:app.character.body.play(action,app.character)
		else:app.character.ground.play(action,app.character)
	if options.has("quality"):
		app.quality = int(options.quality)
		app._apply_quality()
		app._apply_performance_settings()
	if app.has_method("_apply_world_lighting"):
		app._apply_world_lighting()
		app.render_scale = float(options.get("render-scale", "1.0"))
		app.adaptive.reset(app.render_scale)
		app.reduced_renderer.configure(app.render_scale, true, false)
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(960, 600))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 600)
	var result: Dictionary = {"label": str(options.get("label", "sample")), "mode": mode, "engine": Engine.get_version_info().string, "rendering_method": RenderingServer.get_current_rendering_method(), "resolution": "960x600", "quality": app.quality}
	result.render_scale = float(options.get("render-scale", "1.0"))
	result.scene = "supplied sunset" if app.has_method("_apply_world_lighting") else "Phase 4 original illustration"
	result.state = "idle" if idle else "talking"
	result.action = action
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
		if part == "character":
			app.park.visible = false
			if app.get("illustrated") != null:
				app.illustrated.visible = false
				app.illustrated.foreground.visible = false
		var samples: Array[float] = []
		var frames: int = int(options.get("frames", "120"))
		for i in 60 + frames:
			var start: int = Time.get_ticks_usec()
			if part != "park":
				if action.begins_with("walk") and not app.character.ground.active:app.character.ground.play(action,app.character)
				if coordinator:
					app.bridge.state.rms=0. if idle else .06+sin(i*.15)*.04
					app._process(1./30.);Engine.max_fps=0
				else:app.character.mouth = 0.0 if idle else 0.25 + sin(i * 0.15) * 0.20
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
		if app.has_method("_apply_world_lighting") and app.reduced_renderer.active:
			result.character_resolution = str(app.reduced_renderer.viewport.size)
		result.note = "Uncapped wall frame intervals after 60 warmup frames, UI/network disabled. Software renderer if llvmpipe."
	result.bone_writes = app.character.bone_writes
	result.face_writes = app.character.face_writes
	result.static_memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	DirAccess.make_dir_recursive_absolute("res://.local")
	var file: FileAccess = FileAccess.open(str(options.get("output", "res://.local/bench-%s-%s.json" % [result.label, mode])), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("AISORA_BENCH ", JSON.stringify(result))
	DirAccess.remove_absolute(app.settings_path)
	app.queue_free()
	await process_frame
	quit()
