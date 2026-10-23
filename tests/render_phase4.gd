extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func capture() -> Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func changes(a: Image,b: Image,region: Rect2i=Rect2i()) -> int:
 if region.size==Vector2i.ZERO:region=Rect2i(Vector2i.ZERO,a.get_size())
 region=region.intersection(Rect2i(Vector2i.ZERO,a.get_size()))
 var count: int=0
 for y in range(region.position.y,region.end.y):
  for x in range(region.position.x,region.end.x):
   var difference: Color=a.get_pixel(x,y)-b.get_pixel(x,y)
   if absf(difference.r)+absf(difference.g)+absf(difference.b)>.05:count+=1
 return count
func run() -> void:
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(800,600)
 DisplayServer.window_set_size(Vector2i(800,600))
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path="user://phase4-render-missing-%d.cfg"%Time.get_ticks_usec();root.add_child(app)
 app.set_process(false);app.bridge.set_process(false);app.character.set_process(false);app.ui_layer.visible=false;app.character.blink_wait=999
 Engine.max_fps=30
 var park: AisoraIllustratedPark=app.illustrated
 var test_dir: String="user://phase4-render-%d"%Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(test_dir);park.image_storage_dir=test_dir
 # Original synthetic chart verifies aspect preservation without redistributing user pictures.
 var source: Image=Image.create(900,400,false,Image.FORMAT_RGBA8);source.fill(Color("244b96"))
 for y in range(150,251):
  for x in range(400,501):
   if Vector2(x-450,y-200).length()<50:source.set_pixel(x,y,Color("35e85d"))
 source.save_png(test_dir.path_join("chart.png"));check(park.load_local(test_dir.path_join("chart.png")),"Actual image pipeline loads the render chart")
 park.intensity=0;park.apply_performance();park.shadow.visible=false;app.character.visible=false
 var chart: Image=await capture()
 var minimum: Vector2i=Vector2i(99999,99999);var maximum: Vector2i=Vector2i.ZERO
 for y in chart.get_height():
  for x in chart.get_width():
   var pixel: Color=chart.get_pixel(x,y)
   if pixel.g>.65 and pixel.r<.4:
    minimum=minimum.min(Vector2i(x,y));maximum=maximum.max(Vector2i(x,y))
 var extent: Vector2i=maximum-minimum+Vector2i.ONE
 check(extent.x>100 and abs(extent.x-extent.y)<4,"A circle remains round under covered aspect scaling: %s"%extent)
 check(chart.get_pixel(5,5).b>.4 and chart.get_pixel(5,5).g<.5,"Canvas artwork is present behind the 3D world, with no sky replacement")
 var unchanged: Image=await capture();check(changes(chart,unchanged)==0,"Off means the base illustration does not move or warp")
 park.shadow.visible=true
 var shadowed: Image=await capture();check(changes(chart,shadowed)>100,"Separate ground shadow visibly anchors the character location")
 park.shadow.visible=false;app.character.visible=true;app.character.tick(1.0/30.0)
 var character: Image=await capture();check(changes(chart,character)>15000,"The original 3D character renders over the imported illustration")
 var head: Vector3=app.character.skeleton.to_global(app.character.skeleton.get_bone_global_pose(app.character.bone_indices.Head).origin)
 var point: Vector2=app.camera.unproject_position(head)
 var face_region: Rect2i=Rect2i(Vector2i(point)-Vector2i(45,35),Vector2i(90,100))
 app.character._face_weights[1]=0.9;app.character._update_face()
 var speaking: Image=await capture();check(changes(character,speaking,face_region)>4,"Actual mouth morph remains visible in hybrid rendering")
 app.environment_intensity=0;app.petal_density=0
 for preset in [1,2]:
  app.quality=preset;app._apply_quality();app._apply_performance_settings();app.character.visible=true
  var present: Image=await capture();app.character.visible=false
  var absent: Image=await capture()
  check(changes(present,absent)>15000,"Hybrid character and original transparency render in preset %d"%preset)
 app.quality=0;app._apply_quality();app._apply_performance_settings()
 app.character.visible=false
 park.intensity=1;park.density=1;park.apply_performance();park.branches[0].visible=false;park.branches[1].visible=false;park.ambient_material.set_shader_parameter("paused_at",0.0)
 park.petals.material.set_shader_parameter("preview_time",1.0)
 var first: Image=await capture();park.petals.material.set_shader_parameter("preview_time",4.0)
 var moved: Image=await capture();check(changes(first,moved)>60,"2D instanced petals visibly move in the real Compatibility shader")
 park.petals.material.set_shader_parameter("preview_time",-1.0);park.suspended=true
 var paused: Image=await capture();var still: Image=await capture();check(changes(paused,still)==0,"Paused shader effects remain stationary across actual frames")
 park.suspended=false;app.stage_mode=1;app._apply_stage_mode()
 var fallback: Image=await capture();check(changes(chart,fallback)>10000 and app.park.tree_count==8,"The complete optional 3D park renders after a mode switch")
 app.stage_mode=0;app._apply_stage_mode();park.intensity=0;park.apply_performance()
 root.size=Vector2i(1000,600);DisplayServer.window_set_size(Vector2i(1000,600));app._place_character()
 var resized: Image=await capture()
 check(resized.get_size()==Vector2i(1000,600) and park.background.size.x>=1000,"Resize updates the canvas and background coverage")
 check((app.camera.unproject_position(app.character.position)/root.get_visible_rect().size).distance_to(app.character_anchor)<.003,"Character placement survives aspect-ratio changes")
 app.settings_panel.visible=true
 await capture()
 var settings_scroll: ScrollContainer=app.settings_panel.get_child(0)
 check(settings_scroll.get_h_scroll_bar().max_value<=settings_scroll.get_h_scroll_bar().page+1 and app.settings_panel.get_global_rect().end.x<=root.size.x,"Long Phase 4 settings remain within the resizable window without horizontal scrolling")
 app.free()
 for name: String in DirAccess.get_files_at(test_dir):DirAccess.remove_absolute(test_dir.path_join(name))
 DirAccess.remove_absolute(test_dir)
 print("PHASE 4 RENDER TESTS: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
