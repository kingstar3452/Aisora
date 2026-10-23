extends SceneTree
const Client=preload("res://scripts/update_client.gd")
const Budget=preload("res://scripts/background_budget.gd")
const Policy=preload("res://scripts/performance_policy.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func write_json(path: String,data: Dictionary) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data))
func run() -> void:
	var directory: String="user://update-test-%d"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var client: AisoraUpdateClient=Client.new();client.storage=directory;root.add_child(client)
	check(not client.automatic and not client.previews,"Network checks and preview channel default to opt-in")
	check(not client.is_processing(),"Disabled updater consumes no per-frame work")
	check(not client.supported() and not client.check_for_updates(),"Editor/Linux never claims native installation support")
	client.automatic=true;client.previews=true;client.save_preferences();client.free()
	client=Client.new();client.storage=directory;root.add_child(client)
	check(client.automatic and client.previews,"Update preferences persist separately from existing settings")
	client.automatic=false;client.save_preferences()
	client.voice_guard=func():return true
	client.state={"phase":"ready","tag":"v6.2.0"}
	write_json(directory.path_join("plan.json"),{"fixture":true})
	check(not client.download_update(),"Voice prevents download staging")
	client.state.phase="ready"
	check(not client.restart_update(),"Voice prevents restart even with a staged plan")
	client.voice_guard=func():return false;client.state={"phase":"available","tag":"v6.2.0"}
	check(not client.restart_update(),"Available release cannot restart without a fully validated plan")
	var token: String="a".repeat(64)
	write_json(directory.path_join("transaction.json"),{"token":token,"version":client.installed,"previous_version":"6.0.0","phase":"awaiting_health"})
	client._health_token="b".repeat(64);client._ack_health()
	check(not FileAccess.file_exists(directory.path_join("healthy.json")),"Unrelated startup token cannot confirm an installation")
	client._health_token=token;client._ack_health()
	check(client._read("healthy.json").get("version","")==client.installed,"Matching startup can acknowledge health without touching app data")
	client.free()
	var budget: AisoraBackgroundBudget=Budget.new()
	for i in 500:budget.observe(.05,30,true)
	check(budget.factor<1.,"Sustained missed frame budget reduces decoration")
	var unchanged: float=budget.factor
	for i in 500:budget.observe(.2,30,false)
	check(budget.factor==unchanged,"Inactive windows cannot spuriously lower quality")
	budget.reset();check(budget.factor==1.,"Explicit reset restores decoration without changing user preferences")
	var policy: AisoraPerformancePolicy=Policy.new();policy.focused=false
	check(policy.frame_cap(false)==10 and policy.frame_cap(false,true)==30,"Visible unfocused Voice keeps responsive facial cadence")
	policy.low_power=true;check(policy.frame_cap(false,true)==15,"Explicit 15 FPS low-power preference remains respected")
	var config: String=directory.path_join("settings.cfg");var prefs: ConfigFile=ConfigFile.new()
	prefs.set_value("world","override","sunset");prefs.set_value("ground","regions",{"user-calibration":{"width":1.5}});prefs.set_value("bridge","pairing_path","/local/private-bridge.json");prefs.set_value("unknown","preserve",42);prefs.save(config)
	var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=config;root.add_child(app);app.set_process(false);app.bridge.set_process(false);app.character.set_process(false)
	check(app.character.face_clarity and app.character.visual_quality==0,"Low preset retains facial clarity")
	var face_found: bool=false
	for slot: Dictionary in app.character.material_slots:
		if slot.mesh.name=="Face":
			face_found=true
			check(slot.mesh.lod_bias>=100.,"Face keeps full mesh detail on Low")
			check(float(slot.mesh.get_active_material(slot.surface).get_shader_parameter("face_clarity"))==1.,"Facial materials retain gentle readable lighting")
	check(face_found,"Tests use actual Aisora VRM facial surfaces")
	app.bridge.state={"voice":"active","capturing":true,"rms":.12,"connected":true,"pending":false};app.bridge.session_may_be_active=true
	app.adaptive.reset(.5);app._process(1./30.);app.character.tick(1./30.)
	check(app._voice_blocks_update() and app.character._face_weights[1]>.1,"Real VRM mouth responds to simulated fresh Voice while updates are blocked")
	check(app.reduced_renderer.conversation_detail and app.reduced_renderer.scale_factor>=.9,"Voice protects facial render resolution despite prior low scale")
	check(app.illustrated.effect_budget<=.5,"Conversation reduces scenery before character quality")
	app._save();var saved: ConfigFile=ConfigFile.new();saved.load(config)
	check(saved.get_value("unknown","preserve",0)==42 and saved.get_value("bridge","pairing_path","")=="/local/private-bridge.json" and saved.get_value("ground","regions",{}).has("user-calibration"),"Settings writes preserve pairing, calibration and unrelated existing keys")
	app.free()
	for name: String in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("UPDATE TESTS: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
