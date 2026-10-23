extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func capture() -> Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func changes(a: Image,b: Image,region: Rect2i=Rect2i()) -> int:
 if region.size==Vector2i.ZERO:region=Rect2i(Vector2i.ZERO,a.get_size())
 region=region.intersection(Rect2i(Vector2i.ZERO,a.get_size()));var count: int=0
 for y in range(region.position.y,region.end.y):
  for x in range(region.position.x,region.end.x):
   var d: Color=a.get_pixel(x,y)-b.get_pixel(x,y)
   if absf(d.r)+absf(d.g)+absf(d.b)>.06:count+=1
 return count
func show_slot(app: Node,slot: String) -> void:
 var was_suspended: bool=app.illustrated.suspended
 app.illustrated.suspended=false;app.illustrated.select_slot(slot,.2,false);app.illustrated._process(.21);app.illustrated.set_process(false);app.illustrated.suspended=was_suspended;app._apply_world_lighting()
func run() -> void:
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,600);DisplayServer.window_set_size(Vector2i(960,600));Engine.max_fps=30
 var directory: String="user://phase5-render-%d"%Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(directory)
 var settings_path: String=directory.path_join("settings.cfg");var config: ConfigFile=ConfigFile.new();config.set_value("world","override","sunset");config.save(settings_path)
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=settings_path;root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false);app.ui_layer.visible=false
 var park: AisoraIllustratedPark=app.illustrated;park.intensity=0;park.density=0;park.apply_performance();park.suspended=true;park.shadow.visible=false
 app.character.visible=false
 var previous: Image
 DirAccess.make_dir_recursive_absolute("res://.local/phase5-world")
 for slot: String in app.WorldCycle.IMAGE_SLOTS:
  show_slot(app,slot)
  var empty: Image=await capture()
  app.character.visible=true;app.character.tick(1./30.)
  var present: Image=await capture()
  check(changes(empty,present)>12000,"Original lit 3D Aisora is visible over the actual supplied "+slot+" picture")
  if previous!=null:check(changes(previous,empty)>100000,"Separate "+slot+" artwork renders distinctly, not a tint of the previous picture")
  previous=empty
  present.save_png("res://.local/phase5-world/%s.png"%slot);app.character.visible=false
 # Isolate actual alpha composition with flat sources of different aspect ratios.
 for item: Array in [["blue",Color("254bce"),Vector2i(900,400)],["red",Color("de5135"),Vector2i(600,400)]]:
  var image_value: Image=Image.create(item[2].x,item[2].y,false,Image.FORMAT_RGB8);image_value.fill(item[1]);image_value.save_png(directory.path_join(item[0]+".png"))
 park.load_local(directory.path_join("blue.png"),false,false);park.assign_time_image("morning",directory.path_join("red.png"),false)
 var blue: Image=await capture();park.select_slot("morning",1.,false);park.suspended=false;park._process(.5);park.set_process(false)
 var mid: Image=await capture();var pixel: Color=mid.get_pixel(100,300)
 check(pixel.r>.25 and pixel.b>.25 and mid.get_pixel(100,300)!=blue.get_pixel(100,300),"Native Compatibility canvas performs a real smooth alpha crossfade")
 park._process(.5);park.set_process(false);var red: Image=await capture()
 check(red.get_pixel(100,300).r>pixel.r and red.get_pixel(100,300).b<pixel.b,"The fade reaches the second image cleanly")
 park.slot_paths=app.WorldCycle.BUNDLED.duplicate();show_slot(app,"daytime");park.suspended=true
 park.shadow.visible=true;app.character.visible=false;var plain: Image=await capture()
 app.character.visible=true;app.character.tick(1./30.);var native: Image=await capture()
 var native_pixels: int=changes(plain,native)
 app.reduced_renderer.configure(.65,true);app._apply_world_lighting()
 var reduced: Image=await capture()
 check(app.reduced_renderer.viewport.size==Vector2i(624,390) and app.camera.cull_mask==0,"Reduced 3D rendering allocates the requested smaller viewport and culls the native duplicate")
 check(app.reduced_renderer.viewport.world_3d==root.world_3d and app.character.model.find_children("*","MeshInstance3D",true,false).size()==3,"Reduced rendering shares the original world/three meshes, not a duplicate model")
 app.character.visible=false;var reduced_empty: Image=await capture();var reduced_pixels: int=changes(reduced_empty,reduced)
 check(absf(float(native_pixels-reduced_pixels))/maxi(native_pixels,1)<.12 and reduced_pixels>12000,"The reduced render preserves character silhouette, proportions and placement")
 check(changes(plain,reduced_empty)<10,"Transparent reduced rendering leaves the supplied 2D background visible without an opaque rectangle")
 check(changes(native,reduced,Rect2i(0,0,220,600))<10,"Background and UI stay at native resolution outside the 3D character")
 app.character.visible=true
 for preset in [1,2]:
  app.quality=preset;app._apply_quality();app._apply_performance_settings();app._apply_world_lighting()
  var before: Image=await capture();app.character.visible=false;var after: Image=await capture();app.character.visible=true
  check(changes(before,after)>12000,"Reduced 3D Compatibility renders the original character in preset %d"%preset)
 app.quality=0;app._apply_quality();app._apply_performance_settings();app.reduced_renderer.configure(1.,true)
 check(app.camera.cull_mask!=0 and not app.reduced_renderer.layer.visible,"Returning to native restores the original camera and disables the extra render")
 app.character.visible=false;park.shadow.visible=false;park.weather.mode="heavy_rain";park.weather.strength=1.;park.weather.rain_enabled=true;park.weather.clouds_enabled=false;park.weather.apply()
 park.weather.rain.material.set_shader_parameter("preview_time",.5);var rain_a: Image=await capture();park.weather.rain.material.set_shader_parameter("preview_time",1.2);var rain_b: Image=await capture()
 check(changes(rain_a,rain_b)>80,"Instanced rain moves over the supplied artwork in the real shader")
 park.weather.rain.material.set_shader_parameter("preview_time",-1.);park.suspended=false;park.suspended=true
 var paused: Image=await capture();var still: Image=await capture();check(changes(paused,still)==0,"All weather remains stationary while suspended")
 park.weather.mode="clear";park.weather.apply();var clear: Image=await capture();park.weather.mode="misty";park.weather.apply();var mist: Image=await capture()
 check(changes(clear,mist,Rect2i(0,350,960,250))>10000,"Fog is a separate subtle transparent layer above the background")
 app.character.visible=true;park.weather.mode="clear";park.weather.apply();app.ui_layer.visible=true;app.settings_panel.visible=false
 var normal: Image=await capture();check(app.state_label.get_parent()!=app.ui_layer.get_child(0) and not app.state_label.is_visible_in_tree(),"Technical state is collapsed inside settings during normal presentation")
 app._set_clean(true,false);var clean: Image=await capture();check(changes(normal,clean)>100 and not app.ui_layer.visible,"Clean mode removes the small settings control and all diagnostics")
 app.cycle.override_slot="daytime";app.time_override_select.select(2)
 app._toggle_settings();var settings_image: Image=await capture();settings_image.save_png("res://.local/phase5-world/settings.png")
 var scroll: ScrollContainer=app.settings_panel.get_child(0)
 check(scroll.get_h_scroll_bar().max_value<=scroll.get_h_scroll_bar().page+1,"Expanded Phase 5 controls remain usable without horizontal scrolling")
 app.reduced_renderer.configure(.6,true,true);check(app.camera.cull_mask==0 and app.reduced_renderer.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Minimized mode disables 3D redraws without stopping application/Voice processing")
 app.reduced_renderer.configure(1.,true,false)
 app.free()
 for file: String in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(file))
 DirAccess.remove_absolute(directory)
 print("PHASE 5 RENDER TESTS: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
