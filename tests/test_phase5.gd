extends SceneTree
const Cycle=preload("res://scripts/world_cycle.gd")
const Motion=preload("res://scripts/motion_layers.gd")
const Adaptive=preload("res://scripts/adaptive_quality.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func drain(park: AisoraIllustratedPark) -> void:
 var deadline: int=Time.get_ticks_msec()+10000
 while park._worker!=null and Time.get_ticks_msec()<deadline:
  await process_frame;park._process(0.);park.set_process(false)
 check(park._worker==null,"Background worker completes and is joined")
func settle(park: AisoraIllustratedPark) -> void:
 for i in 31:park._process(.1)
 park.set_process(false)
func run() -> void:
 var clock: AisoraWorldCycle=Cycle.new()
 check(clock.slot_at(359)=="nighttime" and clock.slot_at(360)=="morning","Local clock handles midnight wrapping and exact morning boundary")
 check(clock.slot_at(720)=="daytime" and clock.slot_at(1020)=="sunset" and clock.slot_at(1200)=="nighttime","All four default boundaries select their respective images")
 check(not clock.set_boundaries(PackedInt32Array([500,400,1000,1200])) and clock.boundaries[0]==360,"Invalid unordered boundaries retain the working schedule")
 check(clock.set_boundaries(PackedInt32Array([390,720,1080,1260])) and clock.slot_at(719)=="morning","Custom local time boundaries are supported")
 clock.override_slot="sunset";check(clock.slot_at(800)=="sunset","Manual override wins over the local clock")
 var directory: String="user://phase5-test-%d"%Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(directory)
 var legacy: String=directory.path_join("legacy-sunset.png")
 var picture: Image=Image.create(400,225,false,Image.FORMAT_RGB8);picture.fill(Color("cf716e"));picture.save_png(legacy)
 var original_hash: String=FileAccess.get_sha256(legacy)
 var path: String=directory.path_join("settings.cfg")
 var preferences: ConfigFile=ConfigFile.new();preferences.set_value("environment","background_path",legacy);preferences.set_value("world","override","sunset");preferences.set_value("world","fade_seconds",.2);preferences.set_value("custom","keep","old preference");preferences.save(path)
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=path;root.add_child(app);app.set_process(false);app.bridge.set_process(false);app.character.set_process(false)
 var park: AisoraIllustratedPark=app.illustrated;park.image_storage_dir=directory;park.set_process(false)
 check(app.legacy_sunset_path==legacy and FileAccess.get_sha256(legacy)==original_hash,"Phase 4 sunset migrates as an alternative without rewriting any pixels")
 check(park.slot_paths.sunset==Cycle.BUNDLED.sunset and park.background_path!=legacy,"Supplied sunset becomes the default while the old local path is preserved separately")
 for slot: String in Cycle.IMAGE_SLOTS:
  check(FileAccess.file_exists(Cycle.BUNDLED[slot]),"Supplied image exists: "+slot)
  var decoded: Dictionary=park.Images.decode(Cycle.BUNDLED[slot],1280)
  check(decoded.has("image") and decoded.image.get_width()==1280 and decoded.image.get_height() in [720,721],"Actual optimized image decodes within Low's aspect-preserving budget: "+slot)
 check(park.assign_time_image("sunset",legacy,false) and park.select_slot("sunset",.2,false),"Previous local sunset remains selectable")
 settle(park);check(park.displayed_path==legacy,"Selecting the sunset alternative displays its actual local file")
 var old_texture: Texture2D=park.background.texture
 park.slot_paths.morning=directory.path_join("missing.png")
 check(not park.select_slot("morning",.2,false) and park.background.texture==old_texture and park.displayed_path==legacy,"A missing time image keeps the current image intact")
 check(park.lighting_profile().color==Cycle.profile("sunset").color,"Missing slots retain matching displayed-scene lighting, not a fake nighttime recolor")
 park.slot_paths.morning=Cycle.BUNDLED.morning
 check(park.select_slot("morning",1.,false) and park.incoming.visible and park.fade_progress==0.,"Available images begin a two-texture crossfade")
 park._process(.5);park.set_process(false)
 check(park.fade_progress>.49 and park.fade_progress<.51 and park.incoming.modulate.a>.49 and park.incoming.modulate.a<.51,"Crossfade alpha and lighting share the same eased progress")
 var mixed: Color=park.lighting_profile().color
 check(mixed!=Cycle.profile("sunset").color and mixed!=Cycle.profile("morning").color,"Character light interpolates during the image transition")
 settle(park)
 check(park.displayed_slot=="morning" and not park.incoming.visible and park.incoming.texture==null,"Completed fades release the second GPU texture")
 check(not park.is_processing(),"Steady background has no CPU process loop without parallax")
 check(FileAccess.get_sha256(legacy)==original_hash,"Crossfading never overwrites the previous sunset bitmap")
 park.assign_time_image("daytime",legacy);var first_copy: String=park.slot_paths.daytime
 check(park.assign_time_image("daytime",legacy) and park.slot_paths.daytime!=first_copy and FileAccess.file_exists(first_copy),"New assignments use distinct local files and retain previous imports")
 park.slot_paths.daytime=Cycle.BUNDLED.daytime
 check(park.select_slot("daytime",.2,true),"Clock-driven loads support off-thread decode")
 await drain(park);settle(park);check(park.displayed_slot=="daytime","The worker installs the requested image on the main thread")
 park.select_slot("morning",.2,true)
 park.assign_time_image("morning",legacy,false)
 await drain(park);settle(park)
 # drain may have joined the obsolete job and launched the replacement in the same callback.
 if park._worker!=null:await drain(park);settle(park)
 check(park.displayed_path==legacy and park.displayed_slot=="morning","An assignment changed during decode reloads the new file instead of mislabelling old pixels")
 park.slot_paths.morning=Cycle.BUNDLED.morning
 app.weather_mode="heavy_rain";app._apply_performance_settings();app._update_world(true)
 await drain(park);settle(park)
 check(park.displayed_slot=="rain" and park.displayed_path==Cycle.BUNDLED.rain,"Rain overrides the selected time background with the supplied rainy scene")
 app._apply_world_lighting();check(app.character.world_tint==Cycle.profile("rain").color,"Rain has matching cool 3D character lighting")
 app.weather_mode="clear";app.cycle.override_slot="nighttime";app._apply_performance_settings();app._update_world(true)
 await drain(park);settle(park);app._apply_world_lighting()
 check(park.displayed_slot=="nighttime" and app.character.world_energy<.8,"Leaving rain returns to the latest selected time with actual night image and lighting")
 park.weather.strength=1.;park.weather.mode="heavy_rain";park.weather.apply()
 check(park.weather.rain.multimesh.visible_instance_count==64 and park.weather.clouds.visible,"Low heavy rain is one capped instance batch plus a sparse cloud band")
 park.weather.low_power=true;park.weather.apply();check(park.weather.rain.multimesh.visible_instance_count==24,"Low-power reduces heavy rain without affecting Voice")
 park.weather.rain_enabled=false;park.weather.apply();check(not park.weather.rain.visible,"Rain can be disabled independently of its background")
 park.weather.mode="misty";park.weather.low_power=false;park.weather.apply();check(park.weather.fog.visible and not park.weather.clouds.visible,"Misty uses a separate lower-screen transparent fog band")
 park.weather.strength=0;park.weather.apply();check(not park.weather.fog.visible and not park.weather.rain.visible,"Weather strength zero disables animated weather layers")
 park.weather.strength=1;park.weather.nighttime=true;park.weather.night_effects=true;park.weather.mode="clear";park.weather.apply();check(park.weather.fireflies.visible,"Night fireflies are optional separate geometry")
 park.suspended=true;check(float(park.weather.materials[0].get_shader_parameter("paused_at"))>=0.,"Weather shader clocks pause when inactive/minimized")
 park.suspended=false;check(float(park.weather.materials[0].get_shader_parameter("paused_at"))==-1.,"Weather resumes without a CPU simulation catch-up")
 app._set_clean(true);check(not app.ui_layer.visible and app.clean_toggle.button_pressed,"Clean presentation hides all nonessential UI and keeps the checkbox synchronized")
 app.settings_panel.visible=false;app._toggle_settings();check(app.ui_layer.visible and app.settings_panel.visible and not app.clean_toggle.button_pressed,"Tab restores accessible settings from clean mode")
 app.show_ground_guide=true;app._update_ground_guide()
 check(app.ground_guide.visible,"Projected ground guide is available while settings are open")
 app._set_clean(true)
 check(not app.ground_guide.visible,"Clean presentation hides the calibration guide")
 app._set_clean(false);app.settings_panel.visible=true;app._update_ground_guide()
 var editor: LineEdit=LineEdit.new();app.settings_panel.add_child(editor);editor.grab_focus();app.manual_state=-1
 var typed: InputEventKey=InputEventKey.new();typed.pressed=true;typed.keycode=KEY_4;app._input(typed)
 check(app.manual_state==-1,"Typing a number into settings cannot select a conversation test state")
 editor.release_focus();editor.free()
 var ambient=app.ambience
 ambient.advance("morning","clear",false,1.)
 check(ambient.stream==null and not ambient.playing,"Ambience defaults to silent without loading an audio stream")
 ambient.level=.1;ambient.advance("morning","clear",false,1.);ambient.advance("morning","clear",false,1.)
 check(ambient.stream!=null and ambient.playing and ambient._gain>0.,"Optional ambience loads and fades in its original loop")
 ambient.advance("morning","clear",true,1.)
 check(ambient._gain==0. and not ambient.playing,"Conversation guard ducks ambience to silence")
 ambient.level=0.
 var c: AisoraCharacter=app.character
 c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c.state=0;c.tick(1./30.)
 var matched: bool=true
 for bone: String in ["Head","LeftHand","RightHand","Hips"]:
  var calculated: Transform3D=c.pose_safety.joint_pose(bone,c.motion.poses,c.motion.hips_offset)
  matched=matched and calculated.origin.distance_to(c.skeleton.get_bone_global_pose(c.bone_indices[bone]).origin)<.0001
 check(matched,"Cached forward kinematics matches the actual VRM native skeleton")
 for gesture: String in app.ActionCatalog.IDS:
  c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c._safety_tail=0;c.animation_intensity=1.6
  for i in 20:c.tick(1./30.)
  c.play_gesture(gesture)
  var max_hits: int=0;var finite: bool=true
  for i in int(float(Motion.GESTURE_DURATION[gesture])*30)+25:
   c.tick(1./30.)
   if i%3==0:max_hits=maxi(max_hits,c.pose_safety.evaluate(c.motion.poses,c.motion.hips_offset))
   for key: String in c.motion.poses:finite=finite and c.skeleton.get_bone_pose_rotation(c.bone_indices[key]).is_normalized()
  check(finite and max_hits==0,"Actual rig gesture stays finite and outside approximate torso/head/skirt proxies at maximum intensity: "+gesture)
 c.animation_intensity=1.;c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c._safety_tail=0
 for i in 20:c.tick(1./30.)
 c.play_gesture("wave")
 for i in 45:c.tick(1./30.)
 var prior: Quaternion=c.skeleton.get_bone_pose_rotation(c.bone_indices.LeftUpperArm)
 c.play_gesture("hands");c.tick(1./30.)
 check(c.motion.cancelling and prior.angle_to(c.skeleton.get_bone_pose_rotation(c.bone_indices.LeftUpperArm))<.25,"Replacing a gesture queues a fade rather than snapping to rest")
 for i in 150:c.tick(1./30.)
 check(c.motion.last_gesture=="hands","A queued gesture begins after the previous gesture fades")
 c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c._safety_tail=0
 for i in 20:c.tick(1./30.)
 check(not c.ground.play("step_forward",c),"Locomotion refuses uncalibrated image ground")
 c.ground.calibrated=true;c.ground.measure_contacts=true
 var all_return: bool=true;var good_contacts: bool=true;var articulated: bool=true;var bounded: bool=true
 for action: String in c.ground.ACTIONS:
  check(c.ground.play(action,c),"Calibrated articulated movement starts: "+action)
  var frames: int=0;var knee_motion: float=0.;var initial: Vector3=c.position
  while c.ground.active and frames<500:
   c.tick(1./30.);frames+=1
   knee_motion=maxf(knee_motion,c.skeleton.get_bone_pose_rotation(c.bone_indices.LeftLowerLeg).angle_to(c.rest_rotations[c.bone_indices.LeftLowerLeg]))
   bounded=bounded and absf(c.ground.root_offset.x)<c.ground.width*.5 and absf(c.ground.root_offset.z)<c.ground.depth*.5
  all_return=all_return and not c.ground.active and c.position.distance_to(initial)<.0001 and absf(c.rotation.y)<.0001
  good_contacts=good_contacts and c.ground.max_stance_error<.015
  articulated=articulated and knee_motion>.08
 check(all_return,"Every step/turn/pacing sequence returns to its original root anchor")
 check(good_contacts,"Actual native stance foot joints stay within 15 mm of planted targets")
 check(articulated and bounded,"Steps articulate knees and remain inside the calibrated ground bounds")
 c.motion.conversation_active=true;check(not c.ground.play("pace",c),"An active conversation prevents movement from starting")
 c.motion.conversation_active=false;c.ground.play("step_forward",c)
 for i in 45:c.tick(1./30.)
 c.motion.conversation_active=true
 for i in 60:c.tick(1./30.)
 var held: Vector3=c.position
 for i in 30:c.tick(1./30.)
 check(c.position.distance_to(held)<.0001 and c.ground.active,"Voice safely plants the swinging foot and holds further steps")
 c.motion.conversation_active=false
 for i in 250:c.tick(1./30.)
 check(not c.ground.active,"Return steps resume after the conversation ends")
 c.ground.calibrated=true;c.ground.width=1.04;c.ground.depth=.82;app._store_ground_region();var known_slot: String=park.displayed_slot
 park.displayed_slot="daytime";app._load_ground_region();check(not c.ground.calibrated,"Calibration does not leak to another time image")
 park.displayed_slot=known_slot;app._load_ground_region();check(c.ground.calibrated,"Image-specific calibration restores for the matching image path")
 app.night_rest=true;app.rest_after=30;app._idle_duration=40;app.manual_state=-1;app.bridge.state={"voice":"inactive","capturing":false};app.bridge.session_may_be_active=false;app.bridge.command_cooldown=0;app.bridge.state.pending=false;app._process(.1)
 check(c.state==4,"Optional inactive night behavior selects the retained standing rest")
 app.bridge.state.voice="active";app._process(.1);check(c.state==1 and c.motion.conversation_active,"Active Voice wakes nighttime rest and takes presentation priority")
 var auto_quality: AisoraAdaptiveQuality=Adaptive.new();auto_quality.reset(1.);auto_quality.enabled=true
 var changed: bool=false
 for i in 500:changed=auto_quality.observe(.06,30,true) or changed
 check(changed and auto_quality.effective_scale<1.,"Opt-in adaptation responds to sustained slow frames by reducing rendering work")
 auto_quality.reset(1.)
 for i in 500:auto_quality.observe(.2,30,false)
 check(auto_quality.effective_scale==1.,"Inactive/minimized intervals cannot trigger quality changes")
 app._save();check(FileAccess.get_sha256(legacy)==original_hash,"Full settings updates still preserve the old sunset file")
 app.free()
 var restored: Node=load("res://scenes/companion.tscn").instantiate();restored.settings_path=path;root.add_child(restored);restored.set_process(false)
 check(restored.legacy_sunset_path==legacy and restored.illustrated.slot_paths.nighttime==Cycle.BUNDLED.nighttime,"All image assignments and the local sunset alternative persist across launches")
 check(restored.settings.get_value("custom","keep")=="old preference" and restored.night_rest,"Unrelated preferences and new behavior settings survive migration")
 restored.free()
 for file: String in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(file))
 DirAccess.remove_absolute(directory)
 print("PHASE 5 TESTS: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
