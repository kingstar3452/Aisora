extends SceneTree
const Catalog=preload("res://scripts/action_catalog.gd")
const Motion=preload("res://scripts/motion_layers.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool, description: String) -> void:
 checks+=1
 if not condition:failures+=1;printerr("FAIL: ",description)
func at(c: AisoraCharacter, name: String) -> Vector3:
 return c.skeleton.get_bone_global_pose(c.bone_indices[name]).origin
func run() -> void:
 var test_dir: String="user://phase4-%d"%Time.get_ticks_usec();DirAccess.make_dir_recursive_absolute(test_dir)
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=test_dir.path_join("settings.cfg");root.add_child(app)
 app.set_process(false);app.bridge.set_process(false);app.character.set_process(false)
 var c: AisoraCharacter=app.character
 var picture: AisoraIllustratedPark=app.illustrated;picture.image_storage_dir=test_dir
 check(app.stage_mode==0 and not app.park.visible and app.park.petals==null,"Hybrid defaults avoid constructing or rendering fallback geometry")
 check(app.stage_environment.background_mode==Environment.BG_CANVAS and app.stage_environment.background_canvas_max_layer==-1,"Native canvas background is composed below the original 3D world")
 check(c.model!=null and c.skeleton.get_bone_count()>100,"Hybrid uses the actual 3D character and skeleton")
 var source: Image=Image.create(2400,1200,false,Image.FORMAT_RGBA8);source.fill(Color("7799bb"));var source_path: String=test_dir.path_join("source.png");source.save_png(source_path)
 check(picture.load_local(source_path),"PNG imports through the actual local-image pipeline")
 check(picture.background_path.begins_with(test_dir) and picture.background.texture.get_width()==1280,"Local storage is isolated and Low bounds texture width")
 var small: Image=Image.create(80,40,false,Image.FORMAT_RGB8);small.fill(Color("7799bb"))
 small.save_jpg(test_dir.path_join("small.jpg"));small.save_webp(test_dir.path_join("small.webp"))
 check(picture._dimensions(FileAccess.get_file_as_bytes(test_dir.path_join("small.jpg")),"jpg")==Vector2i(80,40),"JPEG dimensions are recognized before allocation")
 check(picture._dimensions(FileAccess.get_file_as_bytes(test_dir.path_join("small.webp")),"webp")==Vector2i(80,40),"WebP dimensions are recognized before allocation")
 var saved: Image=Image.load_from_file(picture.background_path)
 check(saved.get_width()==1920 and saved.get_height()==960,"Saved local source preserves aspect and enough detail for High")
 picture.quality=2;picture.apply_performance()
 check(picture.background.texture.get_width()==1920,"High can restore detail from local source without a download")
 check(picture.load_local(test_dir.path_join("small.jpg"),false,false) and picture.background.texture.get_size()==Vector2(80,40),"Actual JPEG decoding and texture upload preserve dimensions")
 check(picture.load_local(test_dir.path_join("small.webp"),false,false) and picture.background.texture.get_size()==Vector2(80,40),"Actual WebP decoding and texture upload preserve dimensions")
 check(picture.load_local(source_path),"The full selected background restores after format checks")
 var retained: Texture2D=picture.background.texture
 var invalid: String=test_dir.path_join("invalid.png");var bad: FileAccess=FileAccess.open(invalid,FileAccess.WRITE);bad.store_string("Not an image");bad.close()
 check(not picture.load_local(invalid) and picture.background.texture==retained,"Invalid replacement keeps the existing working background")
 check(not picture.load_local(test_dir.path_join("missing.png")) and picture.background.texture==retained,"Missing image does not destroy the working background")
 var oversized: PackedByteArray=PackedByteArray([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,39,16,0,0,39,16])
 var huge: FileAccess=FileAccess.open(test_dir.path_join("huge.png"),FileAccess.WRITE);huge.store_buffer(oversized);huge.close()
 check(not picture.load_local(test_dir.path_join("huge.png")) and picture.background.texture==retained,"Oversized dimensions are rejected before bitmap decoding")
 check(not picture.load_local(source_path,true),"Opaque images cannot accidentally cover Aisora as a foreground overlay")
 var leaf: Image=Image.create(32,32,false,Image.FORMAT_RGBA8);leaf.fill(Color.TRANSPARENT);leaf.fill_rect(Rect2i(8,4,12,20),Color("f4ccde"));leaf.save_png(test_dir.path_join("leaf.png"))
 check(picture.load_local(test_dir.path_join("leaf.png"),true) and not picture.branches[1].visible,"Separate transparent foreground loads without mirroring the supplied artwork")

 picture.intensity=0;picture.apply_performance()
 check(picture.petals.multimesh.visible_instance_count==0 and not picture.branches[0].visible and not picture.is_processing(),"Scenery intensity zero turns off all animated effects")
 picture.intensity=1;picture.density=1;picture.low_power=true;picture.apply_performance()
 check(picture.petals.multimesh.visible_instance_count==12,"2D low-power particles are bounded")
 picture.low_power=false;picture.quality=0;picture.apply_performance()
 check(picture.petals.multimesh.visible_instance_count==24,"Low preset bounds 2D particle count")
 picture.density=0;picture.apply_performance();check(picture.petals.multimesh.visible_instance_count==0,"Particle density zero is an independent off switch")
 picture.parallax=true;picture.apply_performance();picture.suspended=true
 check(not picture.is_processing() and float(picture.petals.material.get_shader_parameter("paused_at"))>=0,"Inactive backgrounds pause shaders and parallax")
 picture.suspended=false;check(float(picture.petals.material.get_shader_parameter("paused_at"))==-1,"Resume restores bounded shader motion")
 app.character_scale=0.75;app.character_anchor=Vector2(.65,.88);app._place_character()
 var projected: Vector2=app.camera.unproject_position(c.position)/root.get_visible_rect().size
 check(projected.distance_to(app.character_anchor)<0.002 and c.scale==Vector3.ONE*.75,"Placement projects the ground anchor and preserves uniform proportions")
 check(picture.shadow.position.distance_to(root.get_visible_rect().size*app.character_anchor-picture.shadow.size*Vector2(.5,.37))<.1,"Ground shadow follows character placement")
 app.stage_mode=1;app._apply_stage_mode()
 check(app.park.visible and app.park.tree_count==8 and app.park.petals!=null,"Optional Phase 3 fallback builds completely on demand")
 check(c.position==Vector3.ZERO and c.scale==Vector3.ONE and app.stage_environment.background_mode==Environment.BG_SKY,"Fallback restores the original 3D staging")
 app.stage_mode=0;app._apply_stage_mode();check(not app.park.visible and app.park.suspended,"Switching back stops hidden park effects")
 # Exercise every actual action, endpoints and native rotations without translating the whole model.
 c.animation_intensity=1.0
 for action: String in Catalog.IDS:
  c.motion=Motion.new(456);c.motion.scheduler_enabled=false;c.state=0;c.blink_wait=999;c.blink_time=-1;c.mouth=0;c.tick(1.0/30.0)
  var root_before: Transform3D=c.transform
  check(c.play_gesture(action),"Standing action starts: "+action)
  var peak_steps: int=roundi(float(Motion.GESTURE_DURATION[action])*.42*30.0)
  for i in peak_steps:c.tick(1.0/30.0)
  c.skeleton.force_update_all_bone_transforms()
  var finite: bool=true
  for bone: String in c.motion.poses:finite=finite and c.skeleton.get_bone_pose_rotation(c.bone_indices[bone]).is_normalized()
  check(finite and c.transform==root_before,"Actual skeleton is finite, with no fake root animation: "+action)
  check(not c.motion.layers.gesture.is_empty(),"Action has a real additive pose: "+action)
  var left: Vector3=at(c,"LeftHand");var right: Vector3=at(c,"RightHand")
  match action:
   "fingers":check(left.y>1.2 and left.z>.15 and c.skeleton.get_bone_pose_rotation(c.bone_indices.LeftIndexProximal).angle_to(c.rest_rotations[c.bone_indices.LeftIndexProximal])>.1,"Finger inspection raises the hand and articulates the actual index joint")
   "hands":check(left.y>1.14 and right.y>1.14 and left.z>.20 and right.z>.20 and left.distance_to(right)>.1,"Both hands are separate and forward of the torso")
   "fold_arms":check(at(c,"LeftIndexDistal").x<0 and at(c,"RightIndexDistal").x>0 and absf(left.y-right.y)>.035 and left.z>.20 and right.z>.19,"Loose folded hands cross at the fingers, with staggered forearms safely forward of the torso")
   "hand_face":check(left.distance_to(at(c,"Head"))<.28 and left.x>.08,"Hand rests near the face without targeting the center of the head")
   "brush_hair":check(right.y>at(c,"Head").y+.02 and absf(right.x)>.08,"Hair brushing reaches the temple/crown outside the face center")
   "stretch":check(left.y>1.35 and right.y>1.35 and left.distance_to(right)>.65,"Both arms stretch visibly upward and outward")
   "back_stretch":check(at(c,"Head").z<-.04,"Back stretch changes the actual torso/head chain")
  for i in int(float(Motion.GESTURE_DURATION[action])*30)-peak_steps+3:c.tick(1.0/30.0)
  check(c.motion.gesture.is_empty(),"Action exits and yields to micro motion: "+action)
 for action: String in Catalog.UNAVAILABLE:check(not c.play_gesture(action),"Unsupported action is refused rather than faked: "+action)
 # Weighted scheduling, single-choice repetition, all-off and conversation cancellation.
 var schedule: AisoraMotionLayers=Motion.new(999);schedule.interval_min=5;schedule.interval_max=5
 for name: String in schedule.action_weights:schedule.action_weights[name]=0.0
 for i in 1200:schedule.tick(.1,0)
 check(schedule.gesture_serial==0,"All-zero weights schedule no actions")
 schedule.action_weights.breathe=1.0
 for i in 600:schedule.tick(.1,0)
 check(schedule.gesture_serial>=4 and schedule.last_gesture=="breathe","A single enabled action can repeat after its configured interval")
 var weighted: AisoraMotionLayers=Motion.new(111);weighted.action_weights={"breathe":5.0,"wave":1.0,"curious":1.0}
 var totals: Dictionary={"breathe":0,"wave":0,"curious":0}
 for i in 500:
  weighted.gesture="";weighted.gesture_wait=0;weighted._update_gesture(.01);totals[weighted.gesture]+=1
 check(totals.breathe>totals.wave and totals.breathe>totals.curious and totals.wave>0,"Weights influence a deterministic nonrepeating random sample")
 schedule.conversation_active=true;schedule.gesture="";schedule.gesture_wait=0;var count_before: int=schedule.gesture_serial
 for i in 100:schedule.tick(.1,0)
 check(schedule.gesture_serial==count_before and not schedule.start_gesture("wave"),"Conversations suppress long random/manual idle actions")
 schedule.conversation_active=false;schedule.start_gesture("wave");schedule.conversation_active=true
 for i in 15:schedule.tick(.1,0)
 check(schedule.gesture.is_empty(),"An active idle action eases out when a conversation begins")
 app.manual_state=-1;app.bridge.state={"connected":true,"voice":"active","activity":"thinking","pending":false,"capturing":false,"rms":0.0,"error":""}
 app.envelope=load("res://scripts/audio_envelope.gd").new();app._process(.1)
 check(c.state==AisoraCharacter.State.THINKING,"Explicit visible thinking metadata selects Thinking")
 check(not app._preview_action("wave") and app.manual_state==-1,"Preview cannot force a Voice session into manual Idle")
 app.bridge.state.activity="unknown";app._process(.1);check(c.state==AisoraCharacter.State.LISTENING,"Silence without a thinking marker stays attentive, not guessed Thinking")
 app.bridge.state.capturing=true;app.bridge.state.rms=.2;app._process(.1)
 check(c.state==AisoraCharacter.State.TALKING and c.mouth>0,"Fresh amplitude overrides thinking/listening and opens the mouth")
 var pairing: String=test_dir.path_join("pair.json");var pair_file: FileAccess=FileAccess.open(pairing,FileAccess.WRITE);pair_file.store_string(JSON.stringify({"key":"a".repeat(64),"port":12345}));pair_file.close()
 check(app.bridge.choose_pairing_file(pairing),"Godot accepts a valid local pairing file")
 var previous_port: int=app.bridge.port
 check(not app.bridge.choose_pairing_file(invalid) and app.bridge.port==previous_port,"Malformed pairing keeps the prior binding without a parser exception")
 app.bridge._received(HTTPRequest.RESULT_SUCCESS,401,PackedStringArray(),"{}".to_utf8_buffer())
 check(str(app.bridge.state.error).contains("Pairing rejected"),"Authentication rejection has an actionable Godot status")
 app.interval_min_slider.value=60;check(app.idle_interval_max>=60,"Minimum interval updates the maximum consistently")
 app.interval_max_slider.value=20;check(app.idle_interval_min<=20,"Maximum interval updates the minimum consistently")
 app._save()
 var stored: ConfigFile=ConfigFile.new();stored.load(app.settings_path)
 check(stored.get_value("environment","background_path")==picture.background_path and stored.get_value("environment","character_x")==.65,"Local picture path and placement persist")
 check(stored.get_value("animation","weights").has("fold_arms") and stored.get_value("bridge","pairing_path")==pairing,"Action weights and the pairing path persist")
 check(not FileAccess.get_file_as_string(app.settings_path).contains("a".repeat(64)),"Settings never contain the local pairing secret")
 # All generated image/config files are isolated under this test directory.
 app.free()
 for name: String in DirAccess.get_files_at(test_dir):DirAccess.remove_absolute(test_dir.path_join(name))
 DirAccess.remove_absolute(test_dir)
 print("PHASE 4 TESTS: ",checks," checks; ",failures," failures")
 quit(1 if failures else 0)
