extends SceneTree
## Local render inspection. Requires a display; -- --sheet captures animation poses/settings.
const Motion = preload("res://scripts/motion_layers.gd")
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280, 800)
	var app: Node = load("res://scenes/companion.tscn").instantiate()
	app.settings_path = "user://preview-no-preferences-%d.cfg" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_process(false)
	app.character.set_process(false)
	app.park.set_process(false)
	app.bridge.set_process(false)
	app.animation_intensity = 1.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			app.quality = int(argument.trim_prefix("--quality="))
	app._apply_quality()
	app._apply_performance_settings()
	var samples: Array[Dictionary] = [{"name": "preview", "state": 0, "seconds": 1.2}]
	if OS.get_cmdline_user_args().has("--sheet"):
		samples = [
			{"name": "phase2-idle", "state": 0, "seconds": 1.2},
			{"name": "phase2-wave", "state": 0, "seconds": 1.6, "gesture": "wave"},
			{"name": "phase2-stretch", "state": 0, "seconds": 1.8, "gesture": "stretch"},
			{"name": "phase2-listening", "state": 1, "seconds": 2.0},
			{"name": "phase2-talking", "state": 3, "seconds": 1.7, "gesture": "explain", "mouth": 0.65},
			{"name": "phase2-sleeping", "state": 4, "seconds": 4.0},
			{"name": "phase2-waking", "state": 1, "seconds": 1.0, "wake": true},
			{"name": "phase2-settings", "state": 0, "seconds": 1.2, "settings": true}
		]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			var names: PackedStringArray = argument.trim_prefix("--only=").split(",")
			samples = samples.filter(func(sample: Dictionary): return names.has(str(sample.name)))
	if samples.is_empty():
		printerr("No matching preview samples")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://.local")
	var failures: int = 0
	for sample: Dictionary in samples:
		app.character.motion = Motion.new(456)
		app.character.state = 0
		app._select_state(int(sample.state) + 1)
		app._process(0.3)
		if sample.get("wake", false):
			app.character.set_state(4)
			for i in 120: app.character.tick(1.0 / 30.0)
		app.character.set_state(int(sample.state))
		if sample.has("gesture"):
			app.character.play_gesture(str(sample.gesture))
		for i in int(float(sample.seconds) * 30.0):
			app.character.mouth = float(sample.get("mouth", 0.0))
			app.character.tick(1.0 / 30.0)
		app.settings_panel.visible = bool(sample.get("settings", false))
		app.character.skeleton.force_update_all_bone_transforms()
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var result: Error = image.save_png("res://.local/%s.png" % sample.name)
		if result != OK: failures += 1
		print("Render ", sample.name, ": ", result)
	print("Render monitors: draw calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), ", primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit(1 if failures else 0)
