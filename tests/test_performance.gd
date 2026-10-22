extends SceneTree
## Actual VRM mesh and pose invariants, independent of benchmark scores.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func run() -> void:
	var path: String="user://performance-test-%d.cfg"%Time.get_ticks_usec()
	var cfg: ConfigFile=ConfigFile.new();cfg.set_value("world","override","sunset");cfg.save(path)
	var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=path;root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false)
	var c: Node=app.character
	# Cache reuse must return exactly the previous standalone query results.
	for sample in 90:
		c.tick(1./30.)
		var names: Array[String]=["Hips","Chest","LeftUpperArm","RightUpperArm"]
		var reference: Array[Transform3D]=[]
		for name_value: String in names:reference.append(c.pose_safety.joint_pose(name_value,c.motion.poses,c.motion.hips_offset))
		c.pose_safety.prepare_pose(c.motion.poses,c.motion.hips_offset)
		for i in names.size():check(c.pose_safety.prepared_joint(names[i]).is_equal_approx(reference[i]),"Shared FK snapshot preserves transforms")
	c.body.play("sit",c)
	for i in 180:
		c.tick(1./30.)
		for leg: RefCounted in c.body._legs:check(leg.transforms[0].inverse().is_equal_approx(leg.transforms[0].affine_inverse()),"IK bases support orthonormal inverse")
	app.free();DirAccess.remove_absolute(path)
	print("PERFORMANCE TESTS: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
