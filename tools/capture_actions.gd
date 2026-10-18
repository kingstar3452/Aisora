extends SceneTree
const Catalog=preload("res://scripts/action_catalog.gd")
const Motion=preload("res://scripts/motion_layers.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(800,800)
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(Vector2i(800,800))
 var app: Node=load("res://scenes/companion.tscn").instantiate()
 app.settings_path="user://gallery-missing-%d.cfg"%Time.get_ticks_usec()
 root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false);app.illustrated.suspended=true;app.ui_layer.visible=false
 Engine.max_fps=30
 var title_layer: CanvasLayer=CanvasLayer.new();title_layer.layer=20;root.add_child(title_layer)
 var label: Label=Label.new();label.position=Vector2(20,15);label.add_theme_color_override("font_color",Color("244942"));label.add_theme_font_size_override("font_size",24);title_layer.add_child(label)
 DirAccess.make_dir_recursive_absolute("res://.local/phase4-actions")
 var sheet: Image=Image.create(960,1600,false,Image.FORMAT_RGBA8)
 var index: int=0
 for action: String in Catalog.IDS:
  var selected: bool=true
  for arg: String in OS.get_cmdline_user_args():
   if arg.begins_with("--action="):selected=arg.trim_prefix("--action=")==action
  if not selected:continue
  for fraction: float in ([0.06,0.25,0.42,0.72,0.96] if action=="look_sides" else [0.06,0.42,0.96]):
   app.character.motion=Motion.new(456);app.character.motion.scheduler_enabled=false;app.character.state=0;app.character.set_state(0)
   app.character.blink_wait=999;app.character.blink_time=-1;app.character.mouth=0
   app.character.tick(1.0/30.0)
   app.character.play_gesture(action)
   for i in int(float(Motion.GESTURE_DURATION[action])*fraction*30.0):app.character.tick(1.0/30.0)
   label.text="%02d  %s  ·  %d%%"%[Catalog.REQUEST_NUMBERS[Catalog.IDS.find(action)],Catalog.LABELS[Catalog.IDS.find(action)],roundi(fraction*100)]
   app.character.skeleton.force_update_all_bone_transforms()
   for i in 3:await process_frame
   await RenderingServer.frame_post_draw
   var picture: Image=root.get_texture().get_image()
   picture.save_png("res://.local/phase4-actions/%s-%d.png"%[action,roundi(fraction*100)])
   if fraction==0.42:
    picture.resize(320,320,Image.INTERPOLATE_LANCZOS);sheet.blit_rect(picture,Rect2i(0,0,320,320),Vector2i(index%3*320,index/3*320))
  print("ACTION CAPTURE: ",action);index+=1
 sheet.save_png("res://.local/phase4-actions/sheet.png")
 app.free();quit()
