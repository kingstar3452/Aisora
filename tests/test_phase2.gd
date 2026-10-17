extends SceneTree
const Motion = preload("res://scripts/motion_layers.gd")
const Policy = preload("res://scripts/performance_policy.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func advance(c: AisoraCharacter, seconds: float) -> void:
	for i in int(ceil(seconds * 30.0)):
		c.tick(1.0 / 30.0)

func run() -> void:
	var app: Node3D = load("res://scenes/companion.tscn").instantiate()
	# Isolate persistence checks from the user's real preferences.
	var preferences_path: String = "user://phase2-test-%d.cfg" % Time.get_ticks_usec()
	var seed_preferences: ConfigFile = ConfigFile.new()
	seed_preferences.set_value("display", "distance", 3.5)
	seed_preferences.set_value("audio", "gain", 6.25)
	seed_preferences.set_value("controls", "voice_key", KEY_F9)
	seed_preferences.set_value("custom", "retain", "existing preference")
	seed_preferences.save(preferences_path)
	app.settings_path = preferences_path
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.park.set_process(false)
	var c: AisoraCharacter = app.character
	c.set_process(false)
	check(app.zoom == 3.5 and app.envelope.gain == 6.25 and app.voice_key == KEY_F9, "Existing camera/audio/shortcut settings load unchanged")
	c.motion = Motion.new(456)
	var original_head: Quaternion = c.skeleton.get_bone_pose_rotation(c.bone_indices.Head)
	advance(c, 1.5)
	check(c.motion.layers.has_all(["breathing", "posture", "gaze", "speech", "gesture"]), "Independent layers are composed")
	check(c.skeleton.get_bone_pose_rotation(c.bone_indices.Head).angle_to(original_head) > 0.025, "Idle head movement is visible")
	check(c.hair_roots.size() == 11, "Only actual head-attached hair roots selected")
	var hair: int = c.hair_roots[0]
	check(c.skeleton.get_bone_pose_rotation(hair).angle_to(c.rest_rotations[hair]) > 0.01, "Hair roots move without springs")
	# Test real gesture poses and simultaneous blink, amplitude and breathing on the asset.
	c.mouth = 0.5
	c.play_gesture("wave")
	advance(c, 1.6)
	c.blink_time = 0.065
	c.tick(0.016)
	check(not c.motion.layers.gesture.is_empty() and not c.motion.layers.breathing.is_empty(), "Gesture and breathing run simultaneously")
	var mouth: Dictionary = c.expressions.aa[0]
	var blink: Dictionary = c.expressions.blink[0]
	check(mouth.mesh.get_blend_shape_value(mouth.shape) > 0.45, "Gesture preserves actual amplitude mouth weight")
	check(blink.mesh.get_blend_shape_value(blink.shape) > 0.6, "Gesture preserves actual blink")
	c.skeleton.force_update_all_bone_transforms()
	var hand: Vector3 = c.skeleton.get_bone_global_pose(c.bone_indices.LeftHand).origin
	var elbow: Vector3 = c.skeleton.get_bone_global_pose(c.bone_indices.LeftLowerArm).origin
	check(hand.y > elbow.y + 0.06, "Wave bends forearm up rather than breaking the elbow")
	for gesture_name: String in ["stretch", "inspect", "settle", "explain", "nod"]:
		check(c.play_gesture(gesture_name), "Gesture available: " + gesture_name)
		advance(c, 1.5)
		var all_valid: bool = true
		for index: int in c.rest_rotations:
			all_valid = all_valid and c.skeleton.get_bone_pose_rotation(index).is_normalized()
		check(all_valid, "Skeleton remains finite: " + gesture_name)
	c.set_state(AisoraCharacter.State.SLEEPING)
	c.tick(1.0 / 30.0)
	check(c.motion.sleep_amount < 0.05, "Sleep eases in instead of snapping")
	advance(c, 3.0)
	check(c.motion.is_resting() and c.motion.gesture.is_empty(), "Sleeping settles and cancels gestures")
	check(blink.mesh.get_blend_shape_value(blink.shape) > 0.99 and mouth.mesh.get_blend_shape_value(mouth.shape) == 0.0, "Rest closes eyes and mouth")
	check(Vector3(c.motion.poses.Head).x > 0.15 and absf(Vector3(c.motion.poses.Head).z) > 0.10, "Rest has visible bowed/tilted head")
	check(c.motion.breath_speed < 0.85, "Sleeping breath rate slows")
	check(not c.play_gesture("wave"), "Sleep refuses awake gestures")
	c.set_state(AisoraCharacter.State.LISTENING)
	c.tick(1.0 / 30.0)
	check(c.motion.sleep_amount > 0.95 and c.motion.wake_time < 0.1, "Wake transition starts from rest pose")
	advance(c, 3.0)
	check(c.motion.sleep_amount == 0.0, "Wake transition completes")
	check(absf(Vector3(c.motion.poses.Head).z) > 0.05, "Listening has attentive head tilt")
	check(c.motion.gaze_target.length() < 0.15, "Listening keeps gaze near conversation partner")
	c.set_state(AisoraCharacter.State.TALKING)
	advance(c, 1.5)
	check(Vector3(c.motion.layers.speech.Head).length() > 0.01, "Speech amplitude drives visible head gesture layer")
	c.mouth = 0.0
	c.tick(1.0 / 30.0)
	check(mouth.mesh.get_blend_shape_value(mouth.shape) == 0.0, "Talking state alone cannot open mouth in silence")
	c.animation_intensity = 0.0
	advance(c, 0.5)
	check(Vector3(c.motion.layers.breathing.Chest) == Vector3.ZERO, "Intensity zero suppresses continuous body motion")
	check(c.skeleton.get_bone_pose_rotation(hair).is_equal_approx(c.rest_rotations[hair]), "Intensity zero resets hair to authored rest")
	# Same seed is reproducible for tests; random schedules vary intervals and avoid repeat clips.
	var first: AisoraMotionLayers = Motion.new(999)
	var second: AisoraMotionLayers = Motion.new(999)
	var deterministic: bool = true
	var varied: bool = false
	var previous: String = ""
	for i in 3600:
		first.tick(1.0 / 30.0, 0.0)
		second.tick(1.0 / 30.0, 0.0)
		deterministic = deterministic and first.poses == second.poses
		if not first.gesture.is_empty() and not previous.is_empty() and first.gesture != previous:
			varied = true
		if not first.gesture.is_empty():
			previous = first.gesture
	check(deterministic, "Seeded schedules are reproducible")
	check(varied and first.gesture_serial >= 5, "Idle scheduler produces varied distinct moments")
	# Rendering limits are separate from Voice. No focus path mutates the bridge.
	var policy: AisoraPerformancePolicy = Policy.new()
	check(policy.frame_cap(false) == 30, "Default active target is 30 FPS")
	policy.low_power = true
	check(policy.frame_cap(false) == 15, "Optional low-power mode is 15 FPS")
	policy.focused = false
	check(policy.frame_cap(false) == 10, "Inactive rendering throttles to 10 FPS")
	policy.minimized = true
	check(policy.frame_cap(false) == 5, "Minimized rendering throttles to 5 FPS")
	policy.focused = true
	policy.minimized = false
	policy.low_power = false
	check(policy.frame_cap(true) == 10, "Settled sleep caps at 10 FPS")
	policy.fps_limit = 0
	check(policy.frame_cap(false) == 15, "Invalid FPS limit is clamped to safe range")
	# Procedural environment structure and actual particle work limits.
	var park: AisoraSakuraPark = app.park
	check(park.tree_count == 8 and park.blossom_batches.size() == 1, "Eight trees share one textured canopy batch")
	check(park.bench.position.x > 0.8 and park.get_node("GardenFurniture").mesh.get_faces().size() > 100, "Small bench and lantern use merged furniture geometry")
	check(park.branch_count == 40 and park.get_node("TreeWood").mesh.get_surface_count() == 1, "Curved trunks and forty branches share one static surface")
	check(park.get_node_or_null("WalkingPath") != null and park.get_node_or_null("GrassGround") != null, "Path and grass exist")
	park.petal_density = 1.0
	park.low_power = false
	park.quality = 2
	park.apply_performance()
	check(park.petals.multimesh.visible_instance_count == 56, "Petal upper bound is 56")
	check(not park.is_processing() and park.petals.multimesh.use_custom_data, "Petals use static GPU seeds without per-frame CPU processing")
	park.suspended = true
	check(float(park.petal_material.get_shader_parameter("pause_time")) >= 0.0, "Inactive/minimized pauses decorative shader time")
	park.suspended = false
	check(float(park.petal_material.get_shader_parameter("pause_time")) == -1.0, "Resume restores analytic petal motion without a CPU catch-up loop")
	park.low_power = true
	park.apply_performance()
	check(park.petals.multimesh.visible_instance_count == 12, "Low-power caps petals at 12")
	park.petal_density = 0.0
	park.apply_performance()
	check(park.petals.multimesh.visible_instance_count == 0, "Particle slider can turn petals off")
	# Restore uses user settings rather than overwriting them; no preferences are saved here.
	app.performance.focused = false
	app.performance.minimized = true
	var bridge_before: Dictionary = app.bridge.state.duplicate(true)
	app._process(0.05)
	check(Engine.max_fps == 5 and app.bridge.process_mode != Node.PROCESS_MODE_DISABLED, "Background policy leaves bridge processing enabled")
	check(app.bridge.state == bridge_before, "Background policy never changes Voice state or ends a session")
	check(ProjectSettings.get_setting("display/window/size/mode") == 0 and ProjectSettings.get_setting("display/window/size/resizable"), "Normal resizable window is explicit default")
	app.animation_intensity = 0.75
	app.petal_density = 0.20
	app.performance.low_power = true
	app.quality = 1
	app._apply_quality()
	app._apply_performance_settings()
	app._save()
	var stored: ConfigFile = ConfigFile.new()
	stored.load(preferences_path)
	check(stored.get_value("animation", "intensity") == 0.75 and stored.get_value("environment", "petal_density") == 0.20 and stored.get_value("performance", "low_power"), "New performance controls persist")
	check(stored.get_value("display", "distance") == 3.5 and stored.get_value("audio", "gain") == 6.25 and stored.get_value("controls", "voice_key") == KEY_F9, "Saving new controls preserves existing camera/audio/shortcut settings")
	check(stored.get_value("custom", "retain") == "existing preference", "Unknown existing preferences are preserved")
	check(root.msaa_3d == Viewport.MSAA_DISABLED and c.low_power and c.animation_intensity == 0.75, "Low-power preset applies without resetting intensity")
	DirAccess.remove_absolute(preferences_path)
	app.queue_free()
	await process_frame
	print("PHASE 2 TESTS: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
