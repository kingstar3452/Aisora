extends SceneTree
## Development-only: distribute the exact running engine's licenses with test builds.
func _initialize() -> void:
 var content: String="Godot Engine "+Engine.get_version_info().string+"\n\n"+Engine.get_license_text()+"\n\nComponent copyrights:\n"+JSON.stringify(Engine.get_copyright_info(),"\t")+"\n\nComponent licenses:\n"+"\n"
 for name: String in Engine.get_license_info():content+="\n=== "+name+" ===\n"+str(Engine.get_license_info()[name])+"\n"
 var file: FileAccess=FileAccess.open("res://docs/licenses/Godot-4.6.3-NOTICES.txt",FileAccess.WRITE)
 if file==null:quit(1);return
 file.store_string(content.strip_edges(false,true)+"\n");file.close();print("Engine notices written.");quit()
