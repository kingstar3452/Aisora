extends SceneTree
## Developer asset preparation. Resize/compress only; never recolor or synthesize scenes.
func _initialize() -> void:
 var source: String=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--source="):source=arg.trim_prefix("--source=")
 if source.is_empty():printerr("Pass -- --source=/directory/containing/the/five/images");quit(1);return
 var mapping: Dictionary={"morning":"morning","afternoon":"daytime","sunset":"sunset","evening":"sunset","night":"nighttime","rain":"rain"}
 var manifest: Dictionary={"description":"User-supplied Phase 5 images; resize/compress only, no recoloring or generated substitutes.","images":{}}
 var manifest_path: String="res://assets/world/manifest.json"
 if FileAccess.file_exists(manifest_path):
  var parser: JSON=JSON.new()
  if parser.parse(FileAccess.get_file_as_string(manifest_path))==OK:manifest=parser.data
 for file: String in DirAccess.get_files_at(source):
  if file.get_basename().to_lower() not in mapping or file.get_extension().to_lower() not in ["png","jpg","jpeg","webp"]:continue
  var slot: String=mapping[file.get_basename().to_lower()]
  var path: String=source.path_join(file)
  var image_value: Image=Image.load_from_file(path)
  if image_value==null or image_value.is_empty():quit(1);return
  var original: Vector2i=image_value.get_size()
  if maxi(original.x,original.y)>1920:
   var ratio: float=1920./maxi(original.x,original.y);image_value.resize(roundi(original.x*ratio),roundi(original.y*ratio),Image.INTERPOLATE_LANCZOS)
  var destination: String="res://assets/world/%s.webp"%slot
  if image_value.save_webp(destination,true,.90)!=OK:quit(1);return
  var keep: FileAccess=FileAccess.open(destination+".import",FileAccess.WRITE);keep.store_string('[remap]\n\nimporter="keep"\n');keep.close()
  manifest.images[slot]={"source_filename":file,"source_sha256":FileAccess.get_sha256(path),"original_width":original.x,"original_height":original.y,"width":image_value.get_width(),"height":image_value.get_height(),"bytes":FileAccess.get_file_as_bytes(destination).size(),"quality":.90,"lossy":true}
  print("OPTIMIZED ",slot,": ",original," -> ",image_value.get_size()," ",manifest.images[slot].bytes," bytes")
 var output: FileAccess=FileAccess.open(manifest_path,FileAccess.WRITE);output.store_string(JSON.stringify(manifest,"  ")+"\n");output.close();quit()
