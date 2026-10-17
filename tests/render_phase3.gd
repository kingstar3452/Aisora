extends SceneTree
## Requires a display: verify actual Compatibility shaders, not a CPU copy of petal math.
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",message)
func capture() -> Image:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func changed_pixels(a: Image,b: Image) -> int:
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	var count: int = 0
	for i in range(0,left.size(),4):
		if abs(int(left[i])-int(right[i]))+abs(int(left[i+1])-int(right[i+1]))+abs(int(left[i+2])-int(right[i+2])) > 12:
			count += 1
	return count
func run() -> void:
	root.size = Vector2i(960,600)
	var app: Node = load("res://scenes/companion.tscn").instantiate()
	app.settings_path = "user://render-phase3-missing-%d.cfg" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_process(false)
	app.bridge.set_process(false)
	app.character.set_process(false)
	app.ui_layer.visible = false
	Engine.max_fps = 30
	app.park.quality = 2
	app.park.petal_density = 1.0
	app.park.apply_performance()
	app.character.visible = false
	for child: Node in app.park.get_children():
		if child is Node3D: child.visible = child == app.park.petals
	var material: ShaderMaterial = app.park.petal_material
	material.set_shader_parameter("preview_time",1.0)
	var first: Image = await capture()
	material.set_shader_parameter("preview_time",3.0)
	var moved: Image = await capture()
	var changes: int = changed_pixels(first,moved)
	check(changes > 40,"Instanced petals visibly move in the actual GL shader (%d pixels)" % changes)
	material.set_shader_parameter("preview_time",-1.0)
	app.park.suspended = true
	var paused: Image = await capture()
	var still: Image = await capture()
	check(changed_pixels(paused,still) == 0,"Paused petals remain visually stationary across rendered frames")
	app.park.suspended = false
	app.park.petal_density = 0
	app.park.apply_performance()
	for child: Node in app.park.get_children():
		if child is Node3D: child.visible = true
	app.character.visible = true
	app.character.tick(1.0/30.0)
	for preset in 3:
		app.quality = preset
		app._apply_quality()
		app._apply_performance_settings()
		var with_character: Image = await capture()
		app.character.visible = false
		var without_character: Image = await capture()
		check(changed_pixels(with_character,without_character) > 10000,"Aisora is rendered clearly in preset %d" % preset)
		app.character.visible = true
	print("PHASE 3 RENDER TESTS: ",checks," checks; ",failures," failures")
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
