extends SceneTree
var app: Node
var checks: int=0
var failures: int=0
var output: String="res://.local/updater-work/facial-render"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func capture() -> Image:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,600);DisplayServer.window_set_size(Vector2i(960,600));Engine.max_fps=30
	DirAccess.make_dir_recursive_absolute(output)
	var path: String="user://facial-render-%d.cfg"%Time.get_ticks_usec();var prefs: ConfigFile=ConfigFile.new();prefs.set_value("world","override","sunset");prefs.save(path)
	app=load("res://scenes/companion.tscn").instantiate();app.settings_path=path;root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false);app.ui_layer.visible=false
	app.illustrated.suspended=true;app.character.motion.scheduler_enabled=false
	for i in 90:app.character.tick(1./30.)
	for quality in 3:
		app.quality=quality;app._apply_quality();app._apply_performance_settings();app._update_face_clearance()
		app.character._face_weights[1]=0.;app.character._update_face()
		var closed: Image=await capture()
		app.character._face_weights[1]=.75;app.character._update_face()
		var opened: Image=await capture();var changed_pixels: int=0;var low: Vector2i=Vector2i(960,600);var high: Vector2i=Vector2i.ZERO
		for y in 600:
			for x in 960:
				var difference: Color=opened.get_pixel(x,y)-closed.get_pixel(x,y)
				if absf(difference.r)+absf(difference.g)+absf(difference.b)>.06:
					changed_pixels+=1;low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
		check(changed_pixels>3,"Actual VRM mouth morph remains visibly rendered in preset "+str(quality))
		check(changed_pixels<2000,"Mouth morph changes stay localized, without moving/warping the environment")
		opened.save_png(output.path_join("mouth-open-%d.png"%quality));closed.save_png(output.path_join("mouth-closed-%d.png"%quality))
		if changed_pixels>0:
			var crop: Rect2i=Rect2i(low-Vector2i(30,30),high-low+Vector2i(61,61)).intersection(Rect2i(0,0,960,600))
			opened.get_region(crop).save_png(output.path_join("face-%d.png"%quality))
		print("FACE RENDER preset=",quality," changed pixels=",changed_pixels)
	app.free();DirAccess.remove_absolute(path)
	print("FACIAL RENDER TESTS: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
