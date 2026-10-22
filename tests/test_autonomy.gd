extends SceneTree
const Autonomy=preload("res://scripts/autonomy.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label_value: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_value)
func run() -> void:
 var a: AisoraAutonomy=Autonomy.new()
 check(a.mode=="talkative" and a.mouse_tracking and a.hover_reactions and a.environment_comments and a.quiet_hours,"Preferred defaults")
 var clock: Dictionary={"year":2026,"month":10,"day":22,"hour":12}
 var context: Dictionary={"focused":true,"scene":"imported_image","environment":"sunset","time_of_day":"daytime","weather":"clear","animation":"idle","state":"idle","effects":{"petals":true}}
 var e: Dictionary=a.request_event("avatar_hover",context,clock,100000.)
 check(not e.is_empty() and e.speech_allowed==false and e.environment=="sunset" and e.time_of_day=="daytime","Accurate displayed image vs clock; never promises speech")
 check(not e.has("position") and not e.has("follow_up") and not e.has("path"),"No cursor or private data in pipeline")
 check(a.request_event("avatar_click",context,clock,100001.).is_empty(),"Cooldown prevents duplicate interruptions")
 check(a.request_event("avatar_hover",context,clock,101000.).is_empty(),"Repeated hover does not loop")
 check(not a.request_event("avatar_click",context,clock,101000.).is_empty(),"Distinct allowed event")
 for key: String in ["paused","dnd","silence"]:
  a.set(key,true);check(a.request_event("environment",context,clock,110000.).is_empty(),key+" suppresses events");a.set(key,false)
 for key: String in ["conversation","voice_uncertain","sleeping"]:
  context[key]=true;check(a.request_event("environment",context,clock,110000.).is_empty(),key+" suppresses events");context[key]=false
 context.focused=false;check(a.request_event("environment",context,clock,110000.).is_empty(),"Inactive suppressed");context.focused=true
 for hour in [22,23,0,7]:check(a.in_quiet_hours(hour),"Overnight quiet hour "+str(hour))
 for hour in [8,12,21]:check(not a.in_quiet_hours(hour),"Awake hour "+str(hour))
 clock.hour=23;check(a.request_event("environment",context,clock,110000.).is_empty(),"Quiet hours block requests");clock.hour=12
 a.quiet_start=8;a.quiet_end=17;check(a.in_quiet_hours(12) and not a.in_quiet_hours(22),"Daytime quiet range")
 a.quiet_start=8;a.quiet_end=8;check(a.in_quiet_hours(12),"Equal hours quiet all day")
 a.quiet_start=22;a.quiet_end=8
 a.count=a.daily_limit;check(a.request_event("environment",context,clock,110000.).is_empty(),"Daily limit enforced")
 clock.day=23;check(not a.request_event("environment",context,clock,200000.).is_empty() and a.count==1,"Local date resets count")
 a.select_mode("quiet");check(a.request_event("avatar_click",context,clock,210000.).is_empty(),"Quiet mode silent")
 a.select_mode("balanced");check(a.cooldown_seconds==1200. and a.daily_limit==3,"Balanced defaults")
 a.select_mode("talkative");check(a.cooldown_seconds==600. and a.daily_limit==6,"Talkative defaults")
 a.local_text=false;e=a.request_event("greeting",context,clock,220000.);check(not e.has("text") and e.delivery=="event_only","Text opt-out")
 var cfg: ConfigFile=ConfigFile.new();a.mouse_tracking=false;a.quiet_hours=false;a.paused=true;a.follow_up="Remember tea";a.save_settings(cfg)
 var b: AisoraAutonomy=Autonomy.new();b.load_settings(cfg)
 check(not b.mouse_tracking and not b.quiet_hours and b.paused and b.follow_up=="Remember tea" and b.last_unix==a.last_unix and b.count==a.count,"Preferences and interruption history persist")
 var file: String="user://autonomy-%d.cfg"%Time.get_ticks_usec();cfg.save(file)
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=file;root.add_child(app);app.set_process(false);app.character.set_process(false);app.bridge.set_process(false)
 check(not app.autonomy.mouse_tracking and app.autonomy.paused,"Existing saved preferences override defaults")
 app.autonomy.paused=false;app.autonomy.mouse_tracking=true;app.autonomy.quiet_hours=true;app._save()
 cfg=ConfigFile.new();cfg.load(file);b=Autonomy.new();b.load_settings(cfg)
 check(b.mouse_tracking and b.quiet_hours and not b.paused,"Application save preserves controls")
 app.character.motion.scheduler_enabled=false;app.character.motion.cursor_target=Vector2(.8,.4);app.character.motion.cursor_eyes=true;app.character.motion.cursor_head=true
 for i in 90:app.character.tick(1./30.)
 check(app.character.motion.cursor_gaze.x>.7,"Cursor smoothly reaches target")
 var index: int=app.character.bone_indices.LeftEye
 check(app.character.skeleton.get_bone_pose_rotation(index).is_finite(),"Actual VRM eye rotation finite")
 app.character.motion.conversation_active=true
 for i in 120:app.character.tick(1./30.)
 check(app.character.motion.cursor_gaze.length()<.001,"Voice fades tracking out")
 app.mouse_awareness.moved(Vector2(480,220));app.mouse_awareness.sample(.1,app);check(not app.mouse_awareness.pending and app.mouse_awareness.target==Vector2.ZERO,"Voice skips unnecessary hit testing and clears queued pointer work")
 var before: float=app.character.mouth;app._update_autonomy(.25);check(app.character.mouth==before,"Autonomy never overrides amplitude mouth")
 app.character.motion.conversation_active=false;app.character.motion.gesture="";app.character.motion.cursor_target=Vector2(100.,-100.)
 # Mouse target clamps before animation; test actual projected avatar hover.
 var head: Vector3=app.character.skeleton.global_transform*app.character.skeleton.get_bone_global_pose(app.character.bone_indices.Head).origin
 app.mouse_awareness.moved(app.camera.unproject_position(head));app.mouse_awareness.sample(.1,app)
 check(app.mouse_awareness.hovered and app.mouse_awareness.target.length()<.01,"Projected avatar hover hits head")
 app.performance.focused=false;app.mouse_awareness.sample(.1,app);check(not app.mouse_awareness.hovered and app.mouse_awareness.target==Vector2.ZERO,"Focus loss clears tracking")
 var actual: Dictionary=app._autonomy_context();check(actual.scene=="imported_image" and actual.environment==app.illustrated.displayed_slot and actual.weather==app.weather_mode,"Environment reports real displayed state")
 app.stage_mode=1;actual=app._autonomy_context();check(actual.scene=="procedural_park" and actual.weather=="clear" and not actual.effects.rain,"Fallback never fabricates image weather")
 check(FileAccess.get_file_as_string("res://config/aisora-personality.md").contains("feisty"),"Version-controlled personality available")
 app.free();DirAccess.remove_absolute(file)
 print("AUTONOMY TESTS: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
