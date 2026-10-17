extends SceneTree
const Diagnostics = preload("res://scripts/frame_diagnostics.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)
func run() -> void:
	var path: String = "user://phase3-test-%d.cfg" % Time.get_ticks_usec()
	var preferences: ConfigFile = ConfigFile.new()
	preferences.set_value("display","quality",1)
	preferences.save(path)
	var app: Node = load("res://scenes/companion.tscn").instantiate()
	app.settings_path = path
	root.add_child(app)
	app.set_process(false)
	app.character.set_process(false)
	app.bridge.set_process(false)
	check(app.quality == 2, "Legacy Standard preference migrates to original-material High")
	var c: AisoraCharacter = app.character
	var offset: Vector3 = Vector3(0.13,-0.20,0.15)
	var basis_rotation: Basis = Basis(Vector3.BACK,offset.z)*Basis(Vector3.RIGHT,offset.x)*Basis(Vector3.UP,offset.y)
	var quaternion_rotation: Quaternion = Quaternion(Vector3.BACK,offset.z)*Quaternion(Vector3.RIGHT,offset.x)*Quaternion(Vector3.UP,offset.y)
	var equivalent: bool = true
	for index: int in c.rest_rotations:
		var axes: Basis = c.parent_rest_axes[index]
		var original: Quaternion = (axes.inverse()*basis_rotation*axes).get_rotation_quaternion()
		var cached: Quaternion = c.parent_inverse_quaternions[index]*quaternion_rotation*c.parent_quaternions[index]
		equivalent = equivalent and original.angle_to(cached) < 0.002
	check(equivalent,"Cached quaternion conversion matches original rest-axis matrix math on every actual bone")
	for preset in 3:
		app.quality = preset
		app._apply_quality()
		app._apply_performance_settings()
		var correct: bool = true
		var textures: bool = true
		for slot: Dictionary in c.material_slots:
			var active: ShaderMaterial = slot.mesh.get_active_material(slot.surface)
			if preset == 2:
				correct = correct and active == slot.original
			else:
				correct = correct and active.next_pass == null and active.shader.resource_path.begins_with("res://assets/character/simple_toon")
			textures = textures and active.get_shader_parameter("_MainTex") == slot.original.get_shader_parameter("_MainTex")
		check(correct,"Preset %d applies efficient materials or restores exact originals" % preset)
		check(textures,"Preset %d retains every source albedo texture" % preset)
		check(root.msaa_3d == (Viewport.MSAA_2X if preset == 2 else Viewport.MSAA_DISABLED),"Only High enables 2x MSAA")
		check(app.park.blossom_batches[0].multimesh.visible_instance_count == [64,80,96][preset],"Canopy detail follows preset without rebuilding geometry")
		app.park.petal_density = 1.0
		app.park.apply_performance()
		check(app.park.petals.multimesh.visible_instance_count == [24,40,56][preset],"Preset limits visible GPU petals")
	var cached_materials: int = c._fast_materials.size()
	c.set_visual_quality(0)
	c.set_visual_quality(1)
	check(c._fast_materials.size() == cached_materials,"Repeated preset switches reuse material resources")
	var material: ShaderMaterial = c.material_slots[0].mesh.get_active_material(c.material_slots[0].surface)
	var before_color: Color = material.get_shader_parameter("_Color")
	c.set_lighting(0.25)
	var dimmed: Color = material.get_shader_parameter("_Color")
	check(dimmed.r < before_color.r and dimmed.a == before_color.a,"Lighting control works with efficient shading and preserves alpha")
	c.set_lighting(1.0)
	check(material.get_shader_parameter("_Color") == before_color,"Lighting adjustment restores authored color without accumulating tint")
	app.performance.low_power = true
	app._apply_quality()
	app._apply_performance_settings()
	check(c.visual_quality == 0 and root.msaa_3d == Viewport.MSAA_DISABLED and app.quality == 2,"Low-power overrides work without losing selected High preference")
	app.performance.low_power = false
	app._apply_performance_settings()
	check(c.visual_quality == 2,"Leaving low-power restores saved visual preset")
	# Unchanged poses and face values must not dirty the native skeleton/blendshape buffers.
	var bone: int = c.bone_indices.Head
	var rotation: Quaternion = c.skeleton.get_bone_pose_rotation(bone)
	var writes: int = c.bone_writes
	c._write_rotation(bone,rotation)
	c._write_rotation(bone,rotation)
	check(c.bone_writes == writes,"Identical rotations do not trigger skeleton writes")
	c._face_weights.fill(0.0)
	c._update_face()
	writes = c.face_writes
	c._update_face()
	check(c.face_writes == writes,"Stable facial values do not upload blendshapes repeatedly")
	c._face_weights[1] = 0.75
	c._update_face()
	var mouth: Dictionary = c.expressions.aa[0]
	check(is_equal_approx(mouth.mesh.get_blend_shape_value(mouth.shape),0.75),"Cached bindings still apply actual amplitude mouth deformation")
	c._face_weights[1] = 0.00001
	c._update_face()
	c._face_weights[1] = 0.0
	c._update_face()
	check(mouth.mesh.get_blend_shape_value(mouth.shape) == 0.0,"Silence closes the mouth exactly even below the write threshold")
	var foreign_shape: int = -1
	var face: MeshInstance3D = mouth.mesh
	for i in face.mesh.get_blend_shape_count():
		if not c._face_shapes.has(i): foreign_shape = i; break
	check(foreign_shape >= 0,"Model has independent imported expressions")
	if foreign_shape >= 0:
		face.set_blend_shape_value(foreign_shape,0.4)
		c._update_face()
		check(is_equal_approx(face.get_blend_shape_value(foreign_shape),0.4),"Optimized facial layers leave unrelated imported expression values intact")
		face.set_blend_shape_value(foreign_shape,0.0)
	c.set_visual_quality(0)
	c.low_power = false
	c._secondary_clock = 0.0
	var hair: int = c.hair_roots[0]
	var hair_before: Quaternion = c.skeleton.get_bone_pose_rotation(hair)
	var head_before: Quaternion = c.skeleton.get_bone_pose_rotation(bone)
	c.tick(1.0/30.0)
	check(c.skeleton.get_bone_pose_rotation(hair) == hair_before,"Low preset skips secondary animation between 8 Hz updates")
	check(c.skeleton.get_bone_pose_rotation(bone) != head_before,"Primary expressive head/body motion continues each frame")
	for i in 4: c.tick(1.0/30.0)
	check(c.skeleton.get_bone_pose_rotation(hair) != hair_before,"Reduced-frequency hair still moves")
	var frame_data: AisoraFrameDiagnostics = Diagnostics.new()
	check(frame_data.snapshot().fps == 0.0,"Diagnostics handle an empty sample window")
	for i in 120: frame_data.record(1.0/30.0)
	check(absf(frame_data.snapshot().fps-30.0) < 0.01,"Diagnostic FPS reports measured frame intervals")
	frame_data.record(0.2)
	check(frame_data.snapshot().mean_ms > 34.0 and frame_data.snapshot().p95_ms < 34.0,"Overlay distinguishes a rare spike from normal p95 pacing")
	frame_data.record(NAN)
	frame_data.record(-1)
	check(frame_data.count == 120 and frame_data.samples.size() == 120,"Diagnostics reject invalid intervals and bound memory")
	for i in 120: frame_data.record(1.0/15.0)
	check(absf(frame_data.snapshot().fps-15.0) < 0.01,"Ring buffer replaces old frame history")
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F3
	event.pressed = true
	app._input(event)
	check(app.diagnostics_visible and app.diagnostics_toggle.button_pressed and app.diagnostics_label.visible,"F3 and settings checkbox stay synchronized")
	app.quality = 1
	app._save()
	app.free()
	var restored: Node = load("res://scenes/companion.tscn").instantiate()
	restored.settings_path = path
	root.add_child(restored)
	check(restored.quality == 1 and restored.character.visual_quality == 1 and restored.diagnostics_visible,"New Balanced preference and overlay persist across application restart")
	restored.free()
	DirAccess.remove_absolute(path)
	print("PHASE 3 TESTS: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
