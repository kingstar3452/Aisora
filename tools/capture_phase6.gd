extends SceneTree
## Developer-only actual-VRM audit. Gray floor/seat are guides, never inferred image geometry.
const Personality=preload("res://scripts/personality.gd")
var app: Node
var c: AisoraCharacter
var directory: String="res://.local/phase6-audit"
func _initialize() -> void:call_deferred("run")
func snapshot(name: String,center: Vector3=Vector3(0,.65,-.1),close: bool=false) -> void:
 for angle: int in [-65,0,65]:
  app.camera.position=center+Vector3(sin(deg_to_rad(angle))*(1.4 if close else 2.9),.38 if close else .65,cos(deg_to_rad(angle))*(1.4 if close else 2.9));app.camera.look_at(center)
  for i in 2:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(directory.path_join("%s-%s.png"%[name,angle]))
func run() -> void:
 var prefs: ConfigFile=ConfigFile.new();prefs.set_value("world","override","sunset");prefs.save("user://phase6-audit.cfg")
 app=load("res://scenes/companion.tscn").instantiate();app.settings_path="user://phase6-audit.cfg";root.add_child(app);app.set_process(false);app.bridge.set_process(false);app.ui_layer.visible=false;c=app.character;c.set_process(false)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(800,800);DisplayServer.window_set_size(Vector2i(800,800));Engine.max_fps=30
 app.illustrated.visible=false;app.illustrated.foreground.visible=false;app.stage_environment.background_mode=Environment.BG_COLOR;app.stage_environment.background_color=Color("a1b2b0")
 var plane: MeshInstance3D=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(6,6);var mat: StandardMaterial3D=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("839e95");plane.material_override=mat;app.add_child(plane)
 DirAccess.make_dir_recursive_absolute(directory)
 c.position=Vector3.ZERO;c.scale=Vector3.ONE;c.ground.reset_origin(c);c.ground.calibrated=true;c.ground.width=2.5;c.ground.depth=2.5;c.body.enabled=true;c.motion.scheduler_enabled=false;c.animation_intensity=1.
 for name: String in ["sit","lie_down","sleep"]:
  if not c.body.play(name,c):printerr("REST REFUSED ",name);quit(1);return
  var frames: int=0
  for mark: int in [30,60,90,120,150,180,220,300]:
   while frames<mark:c.tick(1./30.);frames+=1
   await snapshot(name+"-"+str(mark))
  c.body.play("stand",c)
  for i in 230:c.tick(1./30.)
  await snapshot(name+"-returned")
 for name: String in Personality.IDS:
  c.motion.gesture="";c.motion.queued_gesture="";c.motion.gesture_wait=999.;c.motion.scheduler_enabled=false;c.motion.personality_intensity=1.;c._safety_tail=0.
  c.play_gesture(name)
  for i in int(float(c.motion.GESTURE_DURATION[name])*.45*30):c.tick(1./30.)
  print("PERSONALITY ",name," hits=",c.pose_safety.last_hits," held=",c.pose_safety.blocked_samples)
  await snapshot("personality-"+name,Vector3(0,1.15,0),true)
 app.free();quit()
