extends SceneTree
## Same external CPU-work probe for old/new sources. No FPS or real Voice claim.
var results: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for scenario: String in ["idle","cursor","speaking"]:
  var path: String="user://autonomy-profile-%d.cfg"%Time.get_ticks_usec()
  var cfg: ConfigFile=ConfigFile.new();cfg.set_value("world","override","sunset");cfg.set_value("autonomy","quiet_hours",false);cfg.save(path)
  var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path=path;root.add_child(app)
  app.set_process(false);app.bridge.set_process(false);app.character.set_process(false);app.character.motion.scheduler_enabled=false;app.character.motion.rng.seed=2026;app.character.rng.seed=2026
  app.bridge.state={"voice":"active" if scenario=="speaking" else "inactive","connected":true,"pending":false,"capturing":scenario=="speaking","rms":.12 if scenario=="speaking" else 0.,"activity":"listening"}
  var has_cursor: bool=app.has_method("_unhandled_input") and app.get("autonomy")!=null
  var total: float=0.;var maximum: float=0.;var samples: Array[float]=[]
  for i in 2130:
   var start: int=Time.get_ticks_usec()
   if scenario=="cursor" and i%2==0:
    var event: InputEventMouseMotion=InputEventMouseMotion.new();event.position=Vector2(480+sin(i*.02)*40,220)
    if has_cursor:app._unhandled_input(event)
   app._process(1./30.);app.character.tick(1./30.)
   if i>=330:
    var value: float=(Time.get_ticks_usec()-start)/1000.;total+=value;samples.append(value);maximum=maxf(maximum,value)
  samples.sort()
  results.append({"scenario":scenario,"mean_ms":total/1800.,"median_ms":samples[900],"p95_ms":samples[1710],"p99_ms":samples[1782],"max_ms":maximum,"autonomy_available":has_cursor,"mouth":app.character.mouth,"note":"Headless CPU-only app+actual-VRM tick; scripted output amplitude, no bridge HTTP or render work; 330 warm, 1800 scored"})
  app.free();DirAccess.remove_absolute(path)
 print("AUTONOMY_PROFILE ",JSON.stringify(results));quit()
