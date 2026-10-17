extends SceneTree
## Optional local render check; run with a graphical display and --audio-driver Dummy.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280, 800)
	var scene: Node = load("res://scenes/companion.tscn").instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.local")
	var result: Error = image.save_png("res://.local/preview.png")
	print("Render screenshot: ", result)
	quit(0 if result == OK else 1)
