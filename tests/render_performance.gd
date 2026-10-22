extends SceneTree
## Compare accepted shaders with frozen rc.1 references on the SAME actual VRM pose.
var checks: int=0
var failures: int=0
var app: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func capture() -> Image:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func equivalent(label_value: String) -> void:
	# Compare current character shader programs with frozen rc.1 references.
	# The accepted candidate leaves shader math unchanged; reject accidental drift.
	var swaps: Array[Dictionary]=[]
	for material: ShaderMaterial in app.character._fast_materials.values():
		swaps.append({"material":material,"shader":material.shader})
		material.shader=load("res://tests/reference_shaders/"+material.shader.resource_path.get_file())
	var before: Image=await capture()
	for swap: Dictionary in swaps:swap.material.shader=swap.shader
	var after: Image=await capture();var maximum: float=0.;var changed: int=0
	for y in after.get_height():
		for x in after.get_width():
			var d: Color=after.get_pixel(x,y)-before.get_pixel(x,y);var delta: float=maxf(absf(d.r),maxf(absf(d.g),absf(d.b)));maximum=maxf(maximum,delta)
			if delta>1./255.+.00001:changed+=1
	check(maximum<=1./255.+.00001,"Preserve full render and face pixels in %s (max %.6f, >1LSB pixels %d)"%[label_value,maximum,changed])
	print("VISUAL_EQUIVALENCE ",JSON.stringify({"case":label_value,"max_channel_delta":maximum,"pixels_over_1_lsb":changed}))
	if maximum>1./255.+.00001:
		before.save_png("res://.local/performance-before.png");after.save_png("res://.local/performance-after.png")
func run() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,600);DisplayServer.window_set_size(Vector2i(960,600));Engine.max_fps=30
	var path: String="user://render-performance-%d.cfg"%Time.get_ticks_usec();var cfg: ConfigFile=ConfigFile.new();cfg.set_value("world","override","sunset");cfg.save(path)
	app=load("res://scenes/companion.tscn").instantiate();app.settings_path=path;root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false);app.ui_layer.visible=false;app.illustrated.suspended=true
	app.character.motion.scheduler_enabled=false;app.character.ground.calibrated=true;app.character.ground.width=2.5;app.character.ground.depth=2.5;app.character.body.enabled=true
	for quality in 3:
		app.quality=quality;app._apply_quality();app._apply_performance_settings()
		for pose: String in ["idle","wave","mouth","sit","lie_down"]:
			if pose in ["sit","lie_down"]:
				app.character.body.play(pose,app.character)
				for i in 330:app._process(1./30.);app.character.tick(1./30.)
			elif pose=="wave":
				app.character.play_gesture("wave")
				for i in 45:app.character.tick(1./30.)
			app.character._face_weights[1]=.75 if pose=="mouth" else 0.;app.character._update_face();app.illustrated.suspended=true
			await equivalent("%s-q%d"%[pose,quality])
			if pose in ["sit","lie_down"]:
				app.character.body.play("stand",app.character)
				for i in 250:app._process(1./30.);app.character.tick(1./30.)
			elif pose=="wave":
				for i in 180:app.character.tick(1./30.)
	app.illustrated.suspended=true
	for slot: String in ["morning","daytime","sunset","nighttime","rain"]:
		check(app.illustrated._show_saved(slot),"Use supplied %s image"%slot)
		await equivalent(slot)
		var image_value: Image=Image.create(16,16,false,Image.FORMAT_RGBA8);image_value.fill(Color(.2,.5,.8,1.))
		app.illustrated._begin_fade(slot,"fixture",image_value);app.illustrated.incoming.modulate.a=.5
		await equivalent(slot+"-half-fade")
		app.illustrated.incoming.visible=false;app.illustrated.incoming.texture=null;app.illustrated.fade_progress=1.
	var transparent: Image=Image.create(16,16,false,Image.FORMAT_RGBA8);transparent.fill(Color(.2,.5,.8,.4))
	app.illustrated.background.texture=ImageTexture.create_from_image(transparent)
	check(app.illustrated.background.material==app.illustrated.ambient_material,"Transparent imports retain original alpha blending")
	await equivalent("transparent-image")
	app.reduced_renderer.configure(.65,true,false)
	await equivalent("transparent-reduced-viewport")
	app.free();DirAccess.remove_absolute(path)
	print("PERFORMANCE VISUAL TESTS: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
