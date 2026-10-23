extends SceneTree
var app: Node3D
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("run")
func wait_until(condition: Callable) -> bool:
	for i in 100:
		if condition.call():
			return true
		await create_timer(0.05).timeout
	return false
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)
func run() -> void:
	app = load("res://scenes/companion.tscn").instantiate()
	# Deterministic test defaults without changing or depending on user preferences.
	app.settings_path = "user://live-bridge-test-%d.cfg" % Time.get_ticks_usec()
	root.add_child(app)
	check(await wait_until(func(): return app.bridge.state.get("connected", false)), "Godot connects through the actual local HTTP bridge")
	app.bridge.toggle_voice()
	check(await wait_until(func(): return app.character.state == AisoraCharacter.State.TALKING and app.character.mouth > 0.2), "Command and output amplitude reach TALKING and the mouth")
	var binding: Dictionary = app.character.expressions.aa[0]
	check(binding.mesh.get_blend_shape_value(binding.shape) > 0.15, "Network audio animates the imported mouth shape")
	# Render throttling must not stop the independent browser Voice session or HTTP polling.
	app.performance.focused = false
	app.performance.minimized = true
	check(await wait_until(func(): return Engine.max_fps == 5), "Minimizing throttles rendering")
	await create_timer(1.2).timeout
	check(app.bridge.state.get("voice", "unknown") == "active" and app.bridge.state.get("connected", false), "Active Voice survives background throttling")
	check(app.bridge.age < 0.5, "Bridge continues receiving fresh HTTP state while minimized")
	check(app.character.state == AisoraCharacter.State.TALKING and app.character.mouth > 0.2, "Background output still drives talking")
	app.bridge.toggle_voice()
	check(await wait_until(func(): return app.bridge.state.get("voice", "unknown") == "inactive" and app.character.mouth == 0.0), "End command and silence close the mouth")
	check(app.character.state == AisoraCharacter.State.IDLE, "Inactive Voice returns to idle")
	app.performance.focused = true
	app.performance.minimized = false
	app.fps_limit = 30
	app.performance.low_power = false
	check(await wait_until(func(): return Engine.max_fps == 30), "Restoring focus restores foreground frame cap")
	await wait_until(func(): return not app.bridge.command_pending())
	app.bridge.start_voice()
	check(await wait_until(func(): return app.character.state==AisoraCharacter.State.TALKING and app.character.mouth>0.2),"Explicit start reaches the actual HTTP workflow")
	var original_pairing: String=OS.get_environment("AISORA_BRIDGE_CONFIG")
	var wrong_path: String="user://live-wrong-pair-%d.json"%Time.get_ticks_usec()
	var wrong: FileAccess=FileAccess.open(wrong_path,FileAccess.WRITE);wrong.store_string(JSON.stringify({"key":"2".repeat(64),"port":app.bridge.port}));wrong.close()
	app.bridge.choose_pairing_file(wrong_path)
	check(await wait_until(func(): return str(app.bridge.state.get("error","")).contains("Pairing rejected")) and app.bridge.session_may_be_active,"Real 401 is clear and retains the active-session animation guard")
	app.bridge.choose_pairing_file(original_pairing)
	check(await wait_until(func(): return app.bridge.state.get("voice","")=="active" and app.character.mouth>0.2),"Re-pairing reconnects to the ongoing simulated Voice session")
	await wait_until(func(): return not app.bridge.command_pending())
	app.bridge.start_voice()
	await create_timer(1.0).timeout
	check(app.bridge.state.get("voice","")=="active","Repeated absolute Start does not toggle or create a second session")
	await wait_until(func(): return not app.bridge.command_pending())
	app.bridge.end_voice()
	check(await wait_until(func(): return app.bridge.state.get("voice","")=="inactive" and app.character.mouth==0.0 and not app.bridge.session_may_be_active),"Explicit End closes the mouth and releases the active-session guard")
	DirAccess.remove_absolute(wrong_path)
	print("LIVE LOCAL BRIDGE: ", checks, " checks; ", failures, " failures (browser/audio source simulated)")
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
