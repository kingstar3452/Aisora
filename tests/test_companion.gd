extends SceneTree
const Character = preload("res://scripts/character_controller.gd")
const Envelope = preload("res://scripts/audio_envelope.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func run() -> void:
	var scene: PackedScene = load("res://scenes/companion.tscn")
	check(scene != null, "Main scene loads")
	var app: Node3D = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var c: AisoraCharacter = app.character
	c.set_process(false)
	check(c.model != null, "Actual VRM instantiated")
	check(c.skeleton != null and c.skeleton.get_bone_count() >= 54, "Humanoid skeleton retained")
	for expression_name in ["aa", "blink", "blinkLeft", "blinkRight", "relaxed", "sad"]:
		check(c.expressions.has(expression_name) and not c.expressions[expression_name].is_empty(), "Expression binding: " + expression_name)
	var meshes: Array[Node] = c.model.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 3, "Face, body and hair imported")
	for mesh: MeshInstance3D in meshes:
		var has_texture: bool = false
		for i in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(i)
			if material is ShaderMaterial:
				has_texture = has_texture or material.get_shader_parameter("_MainTex") != null
			elif material is BaseMaterial3D:
				has_texture = has_texture or material.albedo_texture != null
		check(has_texture, "Imported texture: " + mesh.name)
	var mouth_binding: Dictionary = c.expressions.aa[0]
	var blink_binding: Dictionary = c.expressions.blink[0]
	var head: int = c.skeleton.find_bone("Head")
	var head_start: Quaternion = c.skeleton.get_bone_pose_rotation(head)
	c.mouth = 0.6
	c.blink_time = 0.06
	c.tick(0.016)
	check(mouth_binding.mesh.get_blend_shape_value(mouth_binding.shape) > 0.5, "Amplitude reaches real mouth shape")
	check(blink_binding.mesh.get_blend_shape_value(blink_binding.shape) > 0.5, "Blink coexists with speech")
	for state in Character.State.values():
		c.set_state(state)
		# Sleep now has a deliberate 2.4-second ease into its resting pose.
		for i in (90 if state == Character.State.SLEEPING else 30):
			c.tick(1.0 / 30.0)
		check(c.state == state, "State enters: " + Character.STATE_NAMES[state])
		check(c.skeleton.get_bone_pose_rotation(head).is_normalized(), "Finite head rotation: " + Character.STATE_NAMES[state])
	check(c.skeleton.get_bone_pose_rotation(head) != head_start, "Procedural head movement")
	check(blink_binding.mesh.get_blend_shape_value(blink_binding.shape) > 0.95, "Sleeping eyes closed")
	check(mouth_binding.mesh.get_blend_shape_value(mouth_binding.shape) < 0.01, "Sleeping mouth closed")
	var meter: AisoraAudioEnvelope = Envelope.new()
	for i in 30: meter.update(0.12, true, 1.0 / 30.0)
	check(meter.mouth > 0.4 and meter.mouth <= 0.85 and meter.speaking, "Output envelope attack and speech detection")
	for i in 30: meter.update(0.0, true, 1.0 / 30.0)
	check(meter.mouth == 0.0 and not meter.speaking, "Silence closes mouth")
	meter.update(0.12, true, 0.1)
	for i in 30: meter.update(0.9, false, 1.0 / 30.0)
	check(meter.mouth == 0.0 and not meter.speaking, "Stale/disconnected audio closes mouth")
	meter.update(NAN, true, 0.1)
	check(is_finite(meter.mouth), "Invalid amplitude cannot corrupt pose")
	app._select_state(5)
	app._process(0.1)
	check(Engine.max_fps == 10, "Sleeping reduces frame cap")
	app._select_state(0)
	app._process(0.1)
	check(c.state == Character.State.IDLE, "No bridge supports idle/manual workflow")
	check(app.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Camera configured")
	app.queue_free()
	await process_frame
	print("AISORA TESTS: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
