extends SceneTree
const Catalog=preload("res://scripts/action_catalog.gd")
const Motion=preload("res://scripts/motion_layers.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(800,800)
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(Vector2i(800,800))
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path="user://phase5-capture-%d.cfg"%Time.get_ticks_usec();root.add_child(app)
 app.set_process(false);app.character.set_process(false);app.bridge.set_process(false);app.illustrated.suspended=true;app.illustrated.intensity=0;app.illustrated.apply_performance();app.ui_layer.visible=false
 var solid: Image=Image.create(8,8,false,Image.FORMAT_RGB8);solid.fill(Color("a6b9b6"));app.illustrated.background.texture=ImageTexture.create_from_image(solid)
 Engine.max_fps=30
 var title_layer: CanvasLayer=CanvasLayer.new();title_layer.layer=20;root.add_child(title_layer)
 var label: Label=Label.new();label.position=Vector2(18,12);label.add_theme_font_size_override("font_size",23);label.add_theme_color_override("font_color",Color("203933"));title_layer.add_child(label)
 var directory: String="res://.local/phase5-actions";DirAccess.make_dir_recursive_absolute(directory)
 var sheets: Dictionary={}
 for angle: int in [-55,0,55]:sheets[angle]=Image.create(960,1600,false,Image.FORMAT_RGBA8)
 var c: AisoraCharacter=app.character
 var action_index: int=0
 for action: String in Catalog.IDS:
  c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c.state=0;c.blink_wait=999;c.blink_time=-1;c.mouth=0;c._safety_tail=0
  for i in 20:c.tick(1./30.)
  c.play_gesture(action)
  for i in int(float(Motion.GESTURE_DURATION[action])*.42*30):c.tick(1./30.)
  c.skeleton.force_update_all_bone_transforms()
  print("AUDIT ",action," proxy hits=",c.pose_safety.last_hits," held samples=",c.pose_safety.blocked_samples)
  for angle: int in [-55,0,55]:
   var center: Vector3=c.position+Vector3(0,.86,0)
   app.camera.position=center+Vector3(sin(deg_to_rad(angle))*3.2,.1,cos(deg_to_rad(angle))*3.2);app.camera.look_at(center)
   label.text="%02d %s · %d°"%[Catalog.REQUEST_NUMBERS[action_index],Catalog.LABELS[action_index],angle]
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   var picture: Image=root.get_texture().get_image();picture.save_png(directory.path_join("%s-%d.png"%[action,angle]));picture.resize(320,320,Image.INTERPOLATE_LANCZOS)
   sheets[angle].blit_rect(picture,Rect2i(0,0,320,320),Vector2i(action_index%3*320,action_index/3*320))
  action_index+=1
 for angle: int in sheets:sheets[angle].save_png(directory.path_join("sheet-%d.png"%angle))
 app.free();quit()
