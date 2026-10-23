extends SceneTree
## Diagnostic isolation for rejected opaque-background trial ddda536.
## Run with that frozen project/PCK, not the current application.
## Diagnostic isolation only. Both modes animate the same full-detail rig.
## Background-only samples are not application benchmark scores.
func _initialize() -> void:call_deferred("run")
func stats(values: Array[float]) -> Dictionary:
 var sorted: Array[float]=values.duplicate();sorted.sort();var total: float=0.
 for value: float in sorted:total+=value
 return {"mean_ms":total/sorted.size(),"median_ms":sorted[sorted.size()/2],"p95_ms":sorted[int(sorted.size()*.95)],"p99_ms":sorted[int(sorted.size()*.99)]}
func reset(c: Node) -> void:
 c.motion=load("res://scripts/motion_layers.gd").new(2026);c.motion.scheduler_enabled=false;c.rng.seed=2026;c.time=0.;c.blink_wait=2.;c.blink_time=-1.
func run() -> void:
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(960,600);DisplayServer.window_set_size(Vector2i(960,600));DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var app: Node=load("res://scenes/companion.tscn").instantiate();app.settings_path="user://blend-profile-%d.cfg"%Time.get_ticks_usec()
 var cfg: ConfigFile=ConfigFile.new();cfg.set_value("world","override","sunset");cfg.set_value("world","displayed_slot","sunset");cfg.set_value("phase6","version",1);cfg.save(app.settings_path);root.add_child(app)
 app.set_process(false);app.bridge.set_process(false);app.character.set_process(false);app.quality=0;app._apply_quality();app._apply_performance_settings();app._apply_world_lighting();reset(app.character)
 if not ("opaque_material" in app.illustrated):
  var path: String=app.settings_path;app.free();DirAccess.remove_absolute(path);printerr("Use the frozen ddda536 opaque-background trial for this historical diagnostic.");quit(2);return
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 # Warm both shader paths and the actual morph/skinning program before scoring.
 for mode: String in ["mixed","direct"]:
  app.illustrated.background.material=app.illustrated.ambient_material if mode=="mixed" else app.illustrated.opaque_material
  for i in 90:
   app.performance.focused=true;app._process(1./30.);app.character.mouth=.5;app.character.tick(1./30.);Engine.max_fps=0
   await process_frame;await RenderingServer.frame_post_draw
 for repetition in 3:
  for part: String in ["full_animated","background_only"]:
   app.character.visible=part=="full_animated";app.ui_layer.visible=part=="full_animated"
   for mode: String in (["mixed","direct"] if repetition%2==0 else ["direct","mixed"]):
    reset(app.character);app.illustrated.background.material=app.illustrated.ambient_material if mode=="mixed" else app.illustrated.opaque_material
    var frame: Array[float]=[];var renderer: Array[float]=[]
    for i in 240:
     var start: int=Time.get_ticks_usec();app.performance.focused=true;app._process(1./30.);app.character.tick(1./30.);Engine.max_fps=0
     await process_frame;await RenderingServer.frame_post_draw
     if i>=60:frame.append((Time.get_ticks_usec()-start)/1000.);renderer.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
    print("BLEND_PROFILE ",JSON.stringify({"repetition":repetition+1,"part":part,"mode":mode,"frame":stats(frame),"renderer_cpu":stats(renderer),"frame_trace_ms":frame}))
 var path: String=app.settings_path;app.free();DirAccess.remove_absolute(path);quit()
