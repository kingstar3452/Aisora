extends SceneTree
## Opt-in, headless stage timings on the original rig. No per-tick render flush.
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var app: Node=load("res://scenes/companion.tscn").instantiate()
 app.settings_path="user://phase6-profile-%d.cfg"%Time.get_ticks_usec()
 root.add_child(app);app.set_process(false);app.bridge.set_process(false)
 var c: Node=app.character;c.set_process(false);c.motion.scheduler_enabled=false;c.rng.seed=2026
 c.scale=Vector3.ONE;c.position=Vector3.ZERO;c.ground.reset_origin(c);c.ground.calibrated=true;c.ground.width=2.5;c.ground.depth=2.5;c.body.enabled=true
 var results: Dictionary={}
 for state: String in ["idle","talking","walking","seated","sleeping"]:
  c.mouth=0.
  c.set_state(3 if state=="talking" else 0)
  if state=="walking":c.ground.play("walk_forward",c)
  if state in ["seated","sleeping"]:c.body.play("sit" if state=="seated" else "sleep",c)
  for i in 330:c.tick(1./30.)
  c.profiling_enabled=true;c.profile_ticks=0;c.profile_usec=PackedInt64Array([0,0,0,0,0,0])
  var writes: int=c.body.position_writes
  var started: int=Time.get_ticks_usec()
  for i in 1800:
   if state=="walking" and not c.ground.active:c.ground.play("walk_forward",c)
   c.mouth=.25+sin(i*.15)*.2 if state=="talking" else 0.
   c.tick(1./30.)
  results[state]={"total_ms_per_tick":float(Time.get_ticks_usec()-started)/1800000.,"stage_ms":[],"cloth_position_writes":c.body.position_writes-writes}
  for value: int in c.profile_usec:results[state].stage_ms.append(float(value)/1800000.)
  c.profiling_enabled=false
  while c.ground.active:c.tick(1./30.)
  if c.body.active:
   c.body.play("stand",c)
   for i in 240:c.tick(1./30.)
 var output: Dictionary={"engine":Engine.get_version_info().string,"ticks_per_case":1800,"stages":["motion_and_rest","pose_safety","bone_setters","secondary","face","gait_and_rest_ik"],"cases":results,"note":"Headless CPU microbenchmark; 330 warmup ticks. Includes opt-in timing overhead, no native render flush; not a device FPS forecast."}
 FileAccess.open("res://.local/phase6-stage-profile.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"));print("PHASE6_PROFILE ",JSON.stringify(output))
 DirAccess.remove_absolute(app.settings_path);app.free();quit()
