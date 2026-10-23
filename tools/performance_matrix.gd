extends SceneTree
## Identical external harness for all revisions. No production settings are loaded.
## Fixed 1/30 animation inputs, actual render-wall intervals; no animation shortcuts.
var options: Dictionary={}
var errors: int=0
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair: PackedStringArray=argument.trim_prefix("--").split("=",true,1);options[pair[0]]=pair[1]
	call_deferred("run")
func summary(samples: Array[float]) -> Dictionary:
	if samples.is_empty():return {}
	var ordered: Array[float]=samples.duplicate();ordered.sort();var total: float=0.
	for value: float in ordered:total+=value
	return {"mean_ms":total/ordered.size(),"median_ms":ordered[ordered.size()/2],"p95_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"p99_ms":ordered[mini(ordered.size()-1,int(ordered.size()*.99))],"max_ms":ordered.back(),"fps":1000.*ordered.size()/total}
func json_file(path: String,data: Variant) -> void:
	var file: FileAccess=FileAccess.open(path,FileAccess.WRITE)
	if file==null:printerr("FAIL: cannot write benchmark state");quit(1);return
	file.store_string(JSON.stringify(data));file.close()
func tick(app: Node,item: Dictionary,index: int) -> void:
	var c: Node=app.character;var state: String=item.state
	var dt: float=clampf(root.get_process_delta_time(),.001,.1) if bool(item.get("paced",false)) else 1./30.
	if state=="walking" and not c.ground.active:c.ground.play("walk_forward",c)
	if state=="personality" and c.motion.gesture.is_empty():c.play_gesture(str(item.get("gesture","unimpressed")))
	app.performance.focused=not bool(item.get("inactive",false))
	app.bridge._process(dt)
	app._process(dt);c.tick(dt)
	if bool(item.get("paced",false)):Engine.max_fps=15 if bool(item.get("low_power",false)) else int(item.get("cap",10))
	else:Engine.max_fps=0
func run_case(item: Dictionary) -> void:
	var size_value: Vector2i=Vector2i(int(item.get("width",960)),int(item.get("height",600)))
	DisplayServer.window_set_size(size_value);root.size=size_value
	var active_voice: bool=item.state in ["speaking","listening"]
	var mode: Dictionary={"connected":str(item.get("bridge","connected"))=="connected","voice":"active" if active_voice else "inactive","speaking":item.state=="speaking"}
	json_file(str(options.mode_file),mode)
	await create_timer(.25).timeout # Wait only for the test browser fixture to select this case.
	var app: Node=load("res://scenes/companion.tscn").instantiate()
	var cfg_path: String="user://matrix-%d.cfg"%Time.get_ticks_usec();var cfg: ConfigFile=ConfigFile.new()
	var slot: String=str(item.get("slot","daytime"));var weather: String=str(item.get("weather","clear"))
	cfg.set_value("display","preset",int(item.get("quality",0)));cfg.set_value("world","override",slot);cfg.set_value("world","displayed_slot","rain" if weather=="heavy_rain" else slot)
	cfg.set_value("world","weather",weather);cfg.set_value("world","weather_strength",.8);cfg.set_value("world","branches",bool(item.get("branches",false)))
	cfg.set_value("performance","render_scale",float(item.get("render_scale",1.)))
	cfg.set_value("environment","intensity",0. if bool(item.get("effects_off",false)) else .65)
	cfg.set_value("world","night_effects",true)
	cfg.set_value("performance","low_power",bool(item.get("low_power",false)));cfg.set_value("performance","adaptive",false)
	cfg.set_value("phase6","version",1);cfg.save(cfg_path);app.settings_path=cfg_path
	root.add_child(app);app.set_process(false);app.bridge.set_process(false);app.character.set_process(false);app.ui_layer.visible=true
	var c: Node=app.character;c.motion=load("res://scripts/motion_layers.gd").new(2026);c.rng.seed=2026
	app._apply_performance_settings();app._apply_world_lighting()
	if bool(item.get("crossfade",false)):app.illustrated.select_slot("nighttime",30.,false)
	if str(item.get("bridge","connected"))=="offline":app.bridge.pairing_path=cfg_path+"-absent";app.bridge.key="";app.bridge.age=99.
	if item.state in ["walking","sitting","reclining","sleeping"]:
		c.motion.scheduler_enabled=false;c.ground.calibrated=true;c.ground.width=2.5;c.ground.depth=2.5;c.body.enabled=true
		if item.state=="walking":c.ground.play("walk_forward",c)
		else:
			c.body.play({"sitting":"sit","reclining":"lie_down","sleeping":"sleep"}[item.state],c)
			# Enter the actual settled pose before warmup. Transition correctness is
			# separately rendered/tested; these cases measure held rest + full IK.
			for i in 330:app._process(1./30.);c.tick(1./30.)
	if item.state=="personality":c.motion.scheduler_enabled=false;c.play_gesture(str(item.get("gesture","unimpressed")))
	if bool(item.get("inactive",false)):app.performance.focused=false
	var measure_gpu: bool=str(options.get("profile","false"))=="true"
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),measure_gpu)
	var samples: Array[float]=[];var script_samples: Array[float]=[];var cpu_samples: Array[float]=[];var gpu_samples: Array[float]=[]
	var count: int=int(item.get("frames",options.get("frames",180)));var warmup: int=60
	var mouth_max: float=0.;var connected_frames: int=0;var body_frames: int=0
	for i in warmup+count:
		if i==warmup:print("PERF_BEGIN ",JSON.stringify(item))
		var start: int=Time.get_ticks_usec();tick(app,item,i)
		var script_ms: float=(Time.get_ticks_usec()-start)/1000.
		await process_frame;await RenderingServer.frame_post_draw
		if i>=warmup:
			samples.append((Time.get_ticks_usec()-start)/1000.);script_samples.append(script_ms)
			mouth_max=maxf(mouth_max,c.mouth)
			if app.bridge.state.get("connected",false):connected_frames+=1
			if c.body.active or c.ground.active:body_frames+=1
			if measure_gpu:
				cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()));gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	if item.state=="speaking" and mouth_max<.1:errors+=1;printerr("FAIL: speaking case has no actual amplitude-driven mouth")
	if mode.connected and connected_frames<count*.8:errors+=1;printerr("FAIL: connected bridge workload was not sustained")
	if item.state in ["sitting","reclining","sleeping"] and body_frames!=count:errors+=1;printerr("FAIL: rest workload did not stay active")
	var result: Dictionary={"case":item,"frames":count,"frame":summary(samples),"script":summary(script_samples),"engine_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"mouth_max":mouth_max,"connected_frames":connected_frames,"body_frames":body_frames,"renderer_cpu":summary(cpu_samples),"renderer_gpu_query":summary(gpu_samples),"frame_trace_ms":samples,"character_resolution":str(app.reduced_renderer.viewport.size) if app.reduced_renderer.active else str(size_value),"face_clarity":c.face_clarity if "face_clarity" in c else false}
	print("PERF_RESULT ",JSON.stringify(result))
	app.free();DirAccess.remove_absolute(cfg_path)
	await process_frame;await RenderingServer.frame_post_draw
func run() -> void:
	root.content_scale_size=Vector2i.ZERO;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var cases: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(options.cases)))
	if not cases is Array:printerr("FAIL: missing cases");quit(1);return
	print("PERF_ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"os_cpu_count":OS.get_processor_count(),"worker_limit":ProjectSettings.get_setting("threading/worker_pool/max_threads"),"delta":1./30.,"warmup_frames":60}))
	for item: Dictionary in cases:await run_case(item)
	print("PERF_DONE errors=",errors);quit(1 if errors else 0)
