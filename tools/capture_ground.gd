extends SceneTree
const Motion=preload("res://scripts/motion_layers.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(800,800)
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(Vector2i(800,800))
 Engine.max_fps=30
 var preferences: ConfigFile=ConfigFile.new();preferences.set_value("world","override","sunset");preferences.save("res://.local/ground-capture.cfg")
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path="res://.local/ground-capture.cfg";root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false);app.ui_layer.visible=false
 app.illustrated.intensity=0;app.illustrated.apply_performance();app.illustrated.suspended=true;app.illustrated.shadow.visible=false
 var solid: Image=Image.create(8,8,false,Image.FORMAT_RGB8);solid.fill(Color("9eafae"));app.illustrated.background.texture=ImageTexture.create_from_image(solid)
 var c: AisoraCharacter=app.character
 var plane: MeshInstance3D=MeshInstance3D.new();var mesh: PlaneMesh=PlaneMesh.new();mesh.size=Vector2(4,4);plane.mesh=mesh;plane.position=c.position
 var material: StandardMaterial3D=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("879d96");plane.material_override=material;app.add_child(plane)
 var canvas: CanvasLayer=CanvasLayer.new();canvas.layer=20;root.add_child(canvas)
 var label: Label=Label.new();label.position=Vector2(15,15);label.add_theme_color_override("font_color",Color("20352d"));label.add_theme_font_size_override("font_size",23);canvas.add_child(label)
 var directory: String="res://.local/phase6-ground";DirAccess.make_dir_recursive_absolute(directory)
 var moments: Array[float]=[0.,.9,1.3,2.1,2.7,12.]
 for action: String in c.ground.SUPPORTED_ACTIONS:
  var sheet: Image=Image.create(1440,720,false,Image.FORMAT_RGBA8)
  c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c._safety_tail=0;c.state=0;c.blink_wait=999;c.blink_time=-1
  for i in 20:c.tick(1./30.)
  c.ground.calibrated=true;c.ground.width=2.5;c.ground.depth=2.5;c.ground.measure_contacts=true
  if not c.ground.play(action,c):printerr("Capture refused: ",action);quit(1);return
  var frame: int=0
  for column in moments.size():
   var wanted: int=roundi(moments[column]*30)
   while frame<wanted:c.tick(1./30.);frame+=1
   c.skeleton.force_update_all_bone_transforms()
   for row in 3:
    var angle: float=deg_to_rad([-55.,0.,55.][row]);var center: Vector3=c.ground.origin+Vector3(0,.86,0)
    app.camera.position=center+Vector3(sin(angle)*3.2,.1,cos(angle)*3.2);app.camera.look_at(center)
    label.text="%s · %.1fs · %d°"%[action,moments[column],[-55,0,55][row]]
    for i in 3:await process_frame
    await RenderingServer.frame_post_draw
    var picture: Image=root.get_texture().get_image();picture.save_png(directory.path_join("%s-%d-%d.png"%[action,column,row]));picture.resize(240,240,Image.INTERPOLATE_LANCZOS);sheet.blit_rect(picture,Rect2i(0,0,240,240),Vector2i(column*240,row*240))
  sheet.save_png(directory.path_join(action+".png"));print("GROUND AUDIT ",action," stance error=",c.ground.max_stance_error," active=",c.ground.active)
  while c.ground.active:c.tick(1./30.)
 app.free();quit()
