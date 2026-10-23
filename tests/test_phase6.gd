extends SceneTree
const Motion=preload("res://scripts/motion_layers.gd")
const Personality=preload("res://scripts/personality.gd")
const Scheduler=preload("res://scripts/behavior_scheduler.gd")
const Probe=preload("res://tests/rig_surface_probe.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;printerr("FAIL: ",message)
func settle(c: AisoraCharacter,frames: int) -> void:
 for i in frames:c.tick(1./30.)
func run() -> void:
 var path: String="user://phase6-test-%d.cfg"%Time.get_ticks_usec()
 var config: ConfigFile=ConfigFile.new();config.set_value("world","override","sunset");config.save(path)
 var previous_hash: String=FileAccess.get_sha256(path)
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=path;root.add_child(app);app.set_process(false);app.bridge.set_process(false)
 check(FileAccess.file_exists(app.settings_backup_path) and FileAccess.get_sha256(app.settings_backup_path)==previous_hash,"Phase 5 preferences get a byte-preserving one-time rollback backup")
 var backup: String=app.settings_backup_path
 var c: AisoraCharacter=app.character;c.set_process(false);c.motion.scheduler_enabled=false;c.rng.seed=7654
 check(not app.behavior.enabled and not c.body.enabled,"Phase 5 defaults and opted-out major behavior survive upgrade")
 c.position=Vector3.ZERO;c.scale=Vector3.ONE;c.ground.reset_origin(c)
 check(not c.body.play("sit",c),"Uncalibrated seat poses are refused")
 c.ground.calibrated=true;c.ground.width=2.5;c.ground.depth=2.5;c.ground.measure_contacts=true;c.body.enabled=true
 for action: String in c.ground.WALK_ACTIONS:
  check(c.ground.play(action,c),"Articulated movement starts: "+action)
  var frames: int=0;var lift: float=0.;var last_position: Vector3=c.position;var continuous: bool=true
  while c.ground.active and frames<800:
   c.tick(1./30.);frames+=1
   lift=maxf(lift,c.skeleton.get_bone_global_pose(c.bone_indices.LeftFoot).origin.y-.114)
   continuous=continuous and c.position.distance_to(last_position)<.05;last_position=c.position
  check(not c.ground.active and c.position.length()<.0001 and lift>.02 and continuous,"Walking lifts an actual foot, remains continuous and returns home: "+action)
  check(c.ground.max_stance_error<.015,"Native planted foot remains within 15 mm during "+action)
 c.ground.turn_degrees=90.
 check(c.ground.play("turn_left",c),"A larger turn is performed with stepping")
 var yaw: float=0.
 for i in 300:c.tick(1./30.);yaw=maxf(yaw,absf(c.rotation.y))
 check(yaw>1.5 and not c.ground.active and absf(c.rotation.y)<.0001,"Stepped 90-degree turn returns without a planted-foot root spin")
 var safe_neutral: bool=true
 for seed_value in [12,456,656,2026,7654]:
  var sample=Motion.new(seed_value);sample.scheduler_enabled=false;sample.intensity=1.6
  for i in 600:
   var pose: Dictionary=sample.tick(1./30.,0.)
   safe_neutral=safe_neutral and c.pose_safety.evaluate(pose,sample.hips_offset)==0
 check(safe_neutral,"Randomized neutral idle keeps hands outside the skirt proxy at maximum intensity")
 var probe=Probe.new(c)
 var worst_floor: float=INF;var bounds_ok: bool=true
 for action: String in ["sit","lie_down","sleep"]:
  check(c.body.play(action,c),"Calibrated full-body transition starts: "+action)
  var last: Vector3=c.position;var continuous: bool=true
  for frame in 420:
   c.tick(1./30.);continuous=continuous and c.position.distance_to(last)<.045;last=c.position
   if frame%30==29:
    var minima: Dictionary=probe.floor_minima(c)
    for key: String in minima:worst_floor=minf(worst_floor,minima[key])
    for key: String in probe.bounds:
     var box: AABB=probe.bounds[key];bounds_ok=bounds_ok and box.position.x>=-1.25 and box.end.x<=1.25 and box.position.z>=-1.25 and box.end.z<=1.25
  check(continuous and c.body.active and c.body.seat>.99,"Rest enters a stable articulated pose without root jumps: "+action)
  if action=="sleep":
   check(c.motion.sleep_amount>.99 and c.motion.is_resting(),"Floor sleep closes eyes and reaches the settled breathing state")
   settle(c,1200)
   check(absf(c.body._shift)>.001,"Long sleep includes a slow local posture change")
   var shifted: Dictionary=probe.floor_minima(c)
   check(float(shifted.Body)>=-.008 and float(shifted.Hair)>=-.008,"Sleeping posture changes retain actual cloth/hair floor clearance")
  var articulated: bool=c.skeleton.get_bone_pose_rotation(c.bone_indices.LeftLowerLeg).angle_to(c.rest_rotations[c.bone_indices.LeftLowerLeg])>.6 if action=="sit" else c.skeleton.get_bone_pose_rotation(c.bone_indices.Hips).angle_to(c.rest_rotations[c.bone_indices.Hips])>1.
  check(absf(c.rotation.x)<.0001 and articulated,"Floor rest articulates the skeleton rather than rotating the whole model: "+action)
  c.body.play("wake",c);settle(c,240)
  check(not c.body.active and c.position.length()<.0001,"Wake/get-up returns to the original standing anchor: "+action)
  var cloth_restored: bool=true
  for bone in c.skeleton.get_bone_count():
   if "Skirt" in c.skeleton.get_bone_name(bone):cloth_restored=cloth_restored and c.skeleton.get_bone_pose_position(bone).is_equal_approx(c.rest_positions[bone])
  check(cloth_restored,"All actual skirt attachments regain their original positions after "+action)
  c.motion.gesture="";c.motion.queued_gesture="";c.motion.gesture_wait=999.;settle(c,10)
 check(worst_floor>=-.008,"Actual skinned body, face and hair stay within an 8 mm floor tolerance through all sampled rest transitions")
 check(bounds_ok,"Actual skinned rest silhouettes remain within the calibrated ground rectangle")
 for height: float in [.48,.60]:
  c.body.seat_height=height;check(c.body.play("sit",c),"Supported seat calibration height starts")
  settle(c,95);var minima: Dictionary=probe.floor_minima(c)
  check(float(minima.Body)>=-.008,"Seat height keeps actual clothing/shoes above floor")
  c.body.play("stand",c);settle(c,100);c.motion.gesture=""
 c.body.seat_height=.48;c.motion.gesture="";c.motion.queued_gesture="";c.body.play("sleep",c);settle(c,310)
 c.motion.conversation_active=true;c.set_state(c.State.LISTENING);c.tick(1./30.)
 check(c.body.desired=="stand" and not c.body.play("sit",c),"Voice wakes floor sleep and refuses new rest")
 settle(c,240);check(not c.body.active and c.motion.external_sleep==0. and c.state==c.State.LISTENING,"Listening stays active throughout safe get-up")
 c.motion.conversation_active=false;c.set_state(c.State.IDLE);settle(c,60)
 for action: String in Personality.IDS:
  c.motion=Motion.new(656);c.motion.scheduler_enabled=false;c.motion.gesture_wait=999.;c.motion.personality_intensity=1.;c.animation_intensity=1.6;c._safety_tail=0.
  settle(c,20);check(c.play_gesture(action),"Reusable personality action starts: "+action)
  var hits: int=0;var face_changed: bool=false
  for frame in int(float(c.motion.GESTURE_DURATION[action])*30)+30:
   c.tick(1./30.)
   if frame%4==0:hits=maxi(hits,c.pose_safety.evaluate(c.motion.poses,c.motion.hips_offset))
   for value: float in c._personality_last:face_changed=face_changed or value>.02
  check(hits==0,"Actual-rig personality limbs remain outside coarse body proxies: "+action)
  if action not in ["dramatic_turn"]:check(face_changed,"Personality has reusable authored facial expression: "+action)
  check(c.mouth==0. and c._face_weights[1]==0.,"Personality never fabricates Voice mouth amplitude: "+action)
  check(c._personality_last.count(0.)==c._personality_last.size(),"Personality morphs return to neutral: "+action)
 c.motion.conversation_active=true;check(not c.play_gesture("unimpressed"),"Conversation suppresses idle personality interruptions")
 c.motion.conversation_active=false;c.animation_intensity=1.;c.motion=Motion.new(546);c.motion.scheduler_enabled=true
 var scheduler=Scheduler.new(1234);scheduler.enabled=true;scheduler.interval_min=15.;scheduler.interval_max=30.;scheduler.wait=0.
 var violations: int=0;var movements: int=0;var personalities: int=0;var rests: int=0;var observed: Dictionary={}
 # 60 simulated minutes, original VRM at 15 Hz, with recurring conversations and day/night context.
 for frame in 54000:
  var t: float=float(frame)/15.;var voice: bool=fmod(t,180.)>145.
  c.motion.conversation_active=voice;c.ground.paused=voice;c.mouth=.2 if voice and frame%60>30 else 0.;c.set_state(c.State.TALKING if c.mouth>0 else (c.State.LISTENING if voice else c.State.IDLE))
  var action: String=scheduler.tick(1./15.,{"voice":voice,"ready":not c.ground.active and not c.body.active and c.motion.gesture.is_empty(),"ground":true,"rest":true,"period":"nighttime" if t>1800. else "morning"})
  if not action.is_empty():
   if voice:violations+=1
   observed[action]=observed.get(action,0)+1
   if action=="personality":personalities+=1;c.play_gesture(Personality.IDS[scheduler.rng.randi_range(0,9)])
   elif action=="stretch":c.play_gesture(action)
   elif action in c.body.ACTIONS:
    if c.body.play(action,c):rests+=1;c.body.hold_seconds=12.
   else:
    if c.ground.play(action,c):movements+=1
  c.tick(1./15.)
  if not c.position.is_finite():violations+=1
 check(violations==0 and movements>5 and personalities>5 and rests>2,"One-hour actual-VRM simulation exercises varied autonomy without starting actions during Voice")
 c.motion.conversation_active=false;c.ground.paused=false;c.mouth=0.;c.set_state(c.State.IDLE);c.body.play("stand",c);settle(c,600)
 check(not c.body.active and not c.ground.active and c.position.length()<.001,"Extended behavior simulation ends at the original anchor")
 print("PHASE 6 SIMULATION: selected=",scheduler.selected_count," walking=",movements," personality=",personalities," rest=",rests," actions=",observed)
 scheduler=Scheduler.new(1234);scheduler.enabled=true;scheduler.wait=0.;scheduler.weights={"stretch":1.}
 check(scheduler.tick(1.,{"ready":true})=="stretch","Single weighted action remains usable")
 check(scheduler.tick(30.,{"ready":true})=="","Cooldown prevents excessive repetition")
 check(scheduler.tick(600.,{"ready":true})=="stretch","A single choice can repeat after its cooldown without deadlocking recent history")
 app.personality_weights={"smirk":1.};app.last_personality="smirk";c.motion.gesture="";c.motion.queued_gesture="";c.motion.sleep_amount=0.;c.motion.sleep_progress=0.
 check(app._perform_behavior("personality",true),"Single personality choice can repeat after the major scheduler cooldown")
 app.personality_weights={};check(not app._perform_behavior("personality",true),"All-zero personality weights disable selection")
 app.behavior.enabled=true;app.behavior.interval_min=75.;app.personality_intensity=.7;c.ground.calibrated=true;app._store_ground_region();app._save();app.free()
 var restored: Node=load("res://scenes/companion.tscn").instantiate();restored.settings_path=path;root.add_child(restored);restored.set_process(false)
 check(restored.behavior.enabled and restored.behavior.interval_min==75. and is_equal_approx(restored.personality_intensity,.7),"Behavior and personality preferences persist locally")
 check(FileAccess.get_sha256(backup)==previous_hash,"Later launches do not overwrite the Phase 5 rollback backup")
 restored.free();DirAccess.remove_absolute(path);DirAccess.remove_absolute(backup)
 print("PHASE 6 TESTS: ",checks," checks; ",failures," failures; worst sampled floor y=",worst_floor)
 quit(1 if failures else 0)
