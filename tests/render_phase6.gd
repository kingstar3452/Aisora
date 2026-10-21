extends SceneTree
var checks: int=0
var failures: int=0
var app: Node
var output: String="user://phase6-render"
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;printerr("FAIL: ",message)
func capture() -> Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func actor_bounds() -> Rect2i:
 app.character.visible=false;var absent: Image=await capture();app.character.visible=true;var present: Image=await capture()
 var low: Vector2i=present.get_size();var high: Vector2i=Vector2i.ZERO
 for y in present.get_height():
  for x in present.get_width():
   var difference: Color=present.get_pixel(x,y)-absent.get_pixel(x,y)
   if absf(difference.r)+absf(difference.g)+absf(difference.b)>.12:
    low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
 return Rect2i(low,high-low+Vector2i.ONE)
func ticks(count: int) -> void:
 for i in count:app._process(1./30.);app.character.tick(1./30.)
func run() -> void:
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,600);DisplayServer.window_set_size(Vector2i(960,600));Engine.max_fps=30
 var cfg: String="user://phase6-render-%d.cfg"%Time.get_ticks_usec();var prefs: ConfigFile=ConfigFile.new();prefs.set_value("world","override","sunset");prefs.set_value("phase6","version",1);prefs.save(cfg)
 app=load("res://scenes/companion.tscn").instantiate();app.settings_path=cfg;root.add_child(app);app.set_process(false);app.bridge.set_process(false);app.character.set_process(false);app.ui_layer.visible=false;app.performance.focused=true
 app.illustrated.suspended=true;app.illustrated.intensity=0.;app.illustrated.density=0.;app.illustrated.apply_performance();app.illustrated.shadow.visible=false
 app.character.motion.scheduler_enabled=false;app.character.ground.calibrated=true;app.character.ground.width=2.5;app.character.ground.depth=2.5;app.character.body.enabled=true
 DirAccess.make_dir_recursive_absolute(output)
 var original_camera: Transform3D=app.camera.transform
 for action: String in ["sit","lie_down","sleep"]:
  check(app.character.body.play(action,app.character),"Rendered full-body action starts: "+action)
  ticks(330)
  var box: Rect2i=await actor_bounds()
  check(box.size.x>80 and box.size.y>60 and box.position.x>4 and box.end.x<956 and box.position.y>4 and box.end.y<596,"Native camera keeps the whole articulated "+action+" visible")
  var shot: Image=await capture();shot.save_png(output.path_join(action+".png"))
  app.reduced_renderer.configure(.65,true,false)
  var reduced: Rect2i=await actor_bounds()
  check(reduced.get_center().distance_to(box.get_center())<8. and abs(reduced.size.x-box.size.x)<20 and abs(reduced.size.y-box.size.y)<20,"Reduced shared-world rendering preserves "+action+" framing")
  app.reduced_renderer.configure(1.,true,false)
  app.character.body.play("stand",app.character);ticks(250)
 check(app.camera.transform.is_equal_approx(original_camera) and not app.character.body.active,"Rest-camera correction restores original standing framing")
 app.character.body.play("sleep",app.character);ticks(330)
 app.bridge.state={"voice":"active","capturing":true,"rms":.12,"connected":true,"pending":false,"error":""};app.bridge.session_may_be_active=true
 ticks(30)
 check(app.character.body.desired=="stand" and app.character.state==app.Character.State.TALKING and app.character._face_weights[1]>.1,"Simulated fresh Voice amplitude speaks while safely waking")
 check(not app._perform_behavior("unimpressed",true),"Active conversation refuses an idle personality interruption")
 app.bridge.state.rms=0.;app.bridge.state.capturing=false;ticks(30)
 check(app.character.state==app.Character.State.LISTENING and app.character._face_weights[1]<.01,"Voice silence becomes attentive listening without fabricating emotion")
 app.bridge.state.voice="inactive";app.bridge.session_may_be_active=false;ticks(250)
 for quality in 3:
  app.quality=quality;app._apply_quality();app._apply_performance_settings();app.illustrated.intensity=0.;app.illustrated.density=0.;app.illustrated.apply_performance()
  app.character.motion.gesture="";app.character.motion.sleep_amount=0.;app.character.motion.sleep_progress=0.
  check(app.character.body.play("sit",app.character),"Preset accepts calibrated seated rig")
  ticks(100);var box: Rect2i=await actor_bounds()
  check(box.size.x>80 and box.size.y>100,"Seated character remains visible in preset "+str(quality))
  app.character.body.play("stand",app.character);ticks(110)
 app.show_ground_guide=true;app.settings_panel.visible=true;app.ui_layer.visible=true;app._update_ground_guide()
 check(app.ground_guide.visible and app.ground_guide.seat_points.size()==4,"Calibration displays a separate virtual-seat guide")
 app._set_clean(true)
 check(not app.ui_layer.visible and not app.ground_guide.visible,"Clean presentation hides all calibration and technical UI")
 app._set_clean(false);app.settings_panel.visible=true
 var scroll: ScrollContainer=app.settings_panel.find_child("*",true,false) as ScrollContainer
 # Find the actual scroll container without relying on auto-generated node names.
 for node: Node in app.settings_panel.find_children("*","ScrollContainer",true,false):scroll=node
 for i in 3:await process_frame
 check(scroll!=null and scroll.get_h_scroll_bar().max_value<=scroll.get_h_scroll_bar().page+1. and app.settings_panel.get_global_rect().end.x<=root.size.x,"Expanded settings remain usable without horizontal scrolling")
 (await capture()).save_png(output.path_join("settings.png"));app.ui_layer.visible=false;app.settings_panel.visible=false
 app.quality=0;app._apply_quality();app.character.motion.gesture="";app.character.body.play("lie_down",app.character);ticks(230)
 app.weather_mode="light_rain";app._apply_performance_settings();app._update_world(true)
 check(app.character.body.desired=="stand" and app.illustrated.displayed_slot=="sunset","Weather changes request a safe return before replacing the calibrated floor image")
 app.illustrated.suspended=false;app.cycle.transition_seconds=.2
 ticks(250)
 var deadline: int=Time.get_ticks_msec()+10000
 while (app.illustrated._worker!=null or app.illustrated.fade_progress<1.) and Time.get_ticks_msec()<deadline:
  await process_frame;app.illustrated._process(.05);app.illustrated.set_process(false)
 check(app.illustrated.displayed_slot=="rain" and not app.character.body.active,"Rain applies after return without losing the original 3D model")
 app.free();DirAccess.remove_absolute(cfg)
 print("PHASE 6 RENDER TESTS: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
