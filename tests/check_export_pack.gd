## Run externally with --main-pack from an otherwise empty --path directory.
extends SceneTree
func _initialize():call_deferred('run')
func run():
 var failed=false
 for name in ['morning','daytime','sunset','nighttime','rain']:
  var path='res://assets/world/'+name+'.webp'
  var data=FileAccess.get_file_as_bytes(path)
  var value=Image.new();var error=value.load_webp_from_buffer(data)
  print('PACKED IMAGE ',name,': exists=',FileAccess.file_exists(path),' decoded=',error,' size=',value.get_size());failed=failed or error!=OK or value.is_empty()
 var app=load("res://scenes/companion.tscn").instantiate()
 app.settings_path="user://packed-phase5-%d.cfg"%Time.get_ticks_usec()
 root.add_child(app);app.set_process(false);app.bridge.set_process(false)
 for i in 5:await process_frame
 var model_ok=app.character.skeleton.get_bone_count()>40 and app.illustrated.background.texture.get_width()>1000
 print("PACKED MAIN SCENE: ","PASS" if model_ok else "FAIL");failed=failed or not model_ok
 app.free()
 print('PACKED ASSETS: ', 'FAIL' if failed else 'PASS')
 quit(1 if failed else 0)
