class_name AisoraIllustratedPark
extends CanvasLayer
## Imported images behind the native 3D world. At most two background textures during a fade.
signal scenery_changed
const Images=preload("res://scripts/local_images.gd")
const Cycle=preload("res://scripts/world_cycle.gd")
const Weather=preload("res://scripts/weather_layers.gd")
const MAX_TEXTURE_EDGE: int=1920
const MAX_FILE_BYTES: int=20*1024*1024
var background: TextureRect
var incoming: TextureRect
var shadow: TextureRect
var foreground: CanvasLayer
var weather: AisoraWeatherLayers
var petals: MultiMeshInstance2D
var branches: Array[TextureRect]=[]
var shader_materials: Array[ShaderMaterial]=[]
var enabled: bool=true
var intensity: float=.65
var density: float=.45
var quality: int=0
var low_power: bool=false
var parallax: bool=false
var show_branches: bool=false
var shadow_opacity: float=.65
var shadow_softness: float=1.
var character_anchor: Vector2=Vector2(.5,.94)
var character_scale: float=1.
# Legacy path remains the sunset reference; other slots never overwrite its file.
var background_path: String=""
var slot_paths: Dictionary={}
var displayed_slot: String="sunset"
var requested_slot: String="sunset"
var displayed_path: String=""
var image_storage_dir: String="user://"
var foreground_path: String=""
var message: String="No local sunset image. Original placeholder is clearly a fallback."
var suspended: bool=false:
 set(value):
  if suspended==value:return
  suspended=value;_pause_shaders()
var _texture_quality: int=-1
var _pause_start: float=0.
var _offset: float=0.
var _clock: float=0.
var _root: Control
var ambient_material: ShaderMaterial
var _worker: Thread
var _loading_slot: String=""
var _loading_path: String=""
var _loading_edge: int=0
var _queued_slot: String=""
var _target_slot: String=""
var _target_path: String=""
var fade_progress: float=1.
var fade_duration: float=8.
var _fade_from: String="sunset"

func _ready() -> void:
 layer=-1;_offset=Time.get_ticks_msec()/1000.
 _root=Control.new();_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.clip_contents=true;add_child(_root)
 background=_picture();background.texture=load("res://assets/illustrated/original_garden.svg");ambient_material=_shader("ambient");background.material=ambient_material;_root.add_child(background)
 incoming=_picture();incoming.material=ambient_material;incoming.visible=false;_root.add_child(incoming)
 weather=Weather.new();_root.add_child(weather)
 shadow=TextureRect.new();shadow.texture=load("res://assets/illustrated/shadow.svg");shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE;shadow.material=ShaderMaterial.new();shadow.material.shader=load("res://assets/illustrated/contact_shadow.gdshader");_root.add_child(shadow)
 foreground=CanvasLayer.new();foreground.layer=1;add_child(foreground)
 for i in 2:
  var branch: TextureRect=_picture();branch.texture=load("res://assets/illustrated/branch.svg");branch.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;branch.size=Vector2(340,212);branch.flip_h=i==1;branch.material=_shader("breeze");foreground.add_child(branch);branches.append(branch)
 petals=MultiMeshInstance2D.new();petals.multimesh=MultiMesh.new();petals.multimesh.transform_format=MultiMesh.TRANSFORM_2D;petals.multimesh.use_custom_data=true
 var quad: QuadMesh=QuadMesh.new();quad.size=Vector2(10,15);petals.multimesh.mesh=quad;petals.multimesh.instance_count=40
 var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=4618
 for i in 40:
  petals.multimesh.set_instance_transform_2d(i,Transform2D.IDENTITY);petals.multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),0,1))
 petals.multimesh.custom_aabb=AABB(Vector3(-4096,-4096,-1),Vector3(8192,8192,2));petals.texture=load("res://assets/illustrated/petal.svg");petals.material=_shader("petals_2d");foreground.add_child(petals)
 get_viewport().size_changed.connect(resize)
 # Reference migration only: never re-encode, move, truncate or delete the old image.
 if str(slot_paths.get("sunset","")).is_empty() and not background_path.is_empty():slot_paths.sunset=background_path
 background_path=str(slot_paths.get("sunset",background_path))
 var initial: String=displayed_slot if not str(slot_paths.get(displayed_slot,"")).is_empty() else "sunset"
 var found: bool=_show_saved(initial)
 if not found and initial!="sunset":found=_show_saved("sunset")
 if not found:
  for slot: String in Cycle.IMAGE_SLOTS:
   if _show_saved(slot):found=true;message="Saved scene missing · displaying available %s image."%slot;break
 if not found:displayed_slot="sunset";displayed_path="";message="Saved images unavailable · original placeholder fallback only. Assign your images in Settings."
 if not foreground_path.is_empty():load_local(foreground_path,true,false)
 resize();apply_performance()

func _picture() -> TextureRect:
 var value: TextureRect=TextureRect.new();value.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;value.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;value.mouse_filter=Control.MOUSE_FILTER_IGNORE;return value

func _shader(name_value: String) -> ShaderMaterial:
 var value: ShaderMaterial=ShaderMaterial.new();value.shader=load("res://assets/illustrated/%s.gdshader"%name_value);value.set_shader_parameter("time_offset",_offset);shader_materials.append(value);return value

func texture_edge() -> int:return 1280 if low_power else [1280,1600,1920][clampi(quality,0,2)]

func _show_saved(slot: String) -> bool:
 var path: String=str(slot_paths.get(slot,""))
 if path.is_empty():return false
 var decoded: Dictionary=Images.decode(path,texture_edge())
 if decoded.has("error"):message=decoded.error;return false
 background.texture=ImageTexture.create_from_image(decoded.image);displayed_slot=slot;displayed_path=path;_fade_from=slot;_texture_quality=0 if low_power else quality
 message="Displaying local %s image."%slot;return true

func assign_time_image(slot: String,path: String,copy_to_user: bool=true) -> bool:
 if slot not in Cycle.IMAGE_SLOTS:return false
 var decoded: Dictionary=Images.decode(path)
 if decoded.has("error"):message=decoded.error;return false
 var image_value: Image=decoded.image
 var destination: String=path
 if copy_to_user:
  DirAccess.make_dir_recursive_absolute(image_storage_dir)
  # Unique files preserve the existing sunset and all prior user imports for rollback.
  destination=image_storage_dir.path_join("aisora-%s-%d-%d.png"%[slot,Time.get_unix_time_from_system(),Time.get_ticks_usec()])
  if image_value.save_png(destination)!=OK:message="Unable to save the local image. Existing assignment retained.";return false
 slot_paths[slot]=destination
 if slot=="sunset":background_path=destination
 message="%s assigned locally. Existing images were not overwritten."%slot.capitalize();scenery_changed.emit();return true

func load_local(path: String,overlay: bool=false,copy_to_user: bool=true) -> bool:
 # Retain the original API: a plain park import explicitly assigns/displays sunset.
 if not overlay:
  if not assign_time_image("sunset",path,copy_to_user):return false
  _finish_worker();_queued_slot="";_target_slot="";fade_progress=1.;incoming.visible=false;incoming.texture=null
  requested_slot="sunset";_show_saved("sunset");resize();_update_processing();return true
 var decoded: Dictionary=Images.decode(path)
 if decoded.has("error"):message=decoded.error;return false
 var image_value: Image=decoded.image
 if image_value.detect_alpha()==Image.ALPHA_NONE:message="Foreground images need transparency (PNG or WebP).";return false
 var destination: String=path
 if copy_to_user:
  destination=image_storage_dir.path_join("aisora-foreground-%d.png"%Time.get_ticks_usec())
  if image_value.save_png(destination)!=OK:message="Unable to save your local foreground.";return false
 Images.fit(image_value,512);foreground_path=destination;show_branches=true;branches[0].texture=ImageTexture.create_from_image(image_value);branches[1].visible=false
 message="Separate transparent foreground loaded locally.";apply_performance();scenery_changed.emit();return true

func select_slot(slot: String,seconds: float=8.,asynchronous: bool=true) -> bool:
 if slot not in Cycle.IMAGE_SLOTS:return false
 requested_slot=slot;fade_duration=clampf(seconds,.2,30.)
 var path: String=str(slot_paths.get(slot,""))
 if path.is_empty() or not FileAccess.file_exists(path):
  _queued_slot="";message="%s image missing · keeping the existing %s image and its lighting."%[slot.capitalize(),displayed_slot];return false
 if slot==displayed_slot and path==displayed_path and fade_progress>=1.:
  message="Displaying local %s image."%slot;return true
 if _worker!=null or fade_progress<1.:
  _queued_slot=slot;return true
 if asynchronous:
  _loading_slot=slot;_loading_path=path;_loading_edge=texture_edge();_worker=Thread.new();_worker.start(Images.decode.bind(path,_loading_edge));message="Loading %s locally; the existing image remains visible…"%slot;_update_processing()
 else:
  var decoded: Dictionary=Images.decode(path,texture_edge())
  if decoded.has("error"):message=decoded.error;return false
  _begin_fade(slot,path,decoded.image)
 return true

func _begin_fade(slot: String,path: String,image_value: Image) -> void:
 incoming.texture=ImageTexture.create_from_image(image_value);incoming.modulate=Color(1,1,1,0);incoming.visible=true
 _target_slot=slot;_target_path=path;_fade_from=displayed_slot;fade_progress=0.;message="Crossfading to %s…"%slot;_update_processing()

func _finish_worker() -> void:
 if _worker!=null:_worker.wait_to_finish();_worker=null;_loading_slot=""

func _exit_tree() -> void:_finish_worker()

func lighting_profile() -> Dictionary:
 var a: Dictionary=Cycle.profile(_fade_from if fade_progress<1. else displayed_slot)
 if fade_progress>=1.:return a
 var b: Dictionary=Cycle.profile(_target_slot)
 var weight: float=smoothstep(0.,1.,fade_progress)
 return {"color":Color(a.color).lerp(b.color,weight),"energy":lerpf(a.energy,b.energy,weight),"ambient":lerpf(a.ambient,b.ambient,weight)}

func resize() -> void:
 if background==null:return
 var extent: Vector2=get_viewport().get_visible_rect().size
 var margin: float=12. if parallax else 0.
 for picture: TextureRect in [background,incoming]:picture.position=Vector2(-margin,-margin);picture.size=extent+Vector2.ONE*margin*2.
 shadow.size=Vector2(230,48)*character_scale;update_character_shadow()
 branches[0].position=Vector2.ZERO;branches[1].position=Vector2(extent.x-340,0)
 petals.material.set_shader_parameter("viewport_size",extent);weather.resize(extent)

func update_character_shadow() -> void:
 # Motion changes only this contact anchor, not image/particle layout uniforms.
 shadow.position=get_viewport().get_visible_rect().size*character_anchor-shadow.size*Vector2(.5,.37)

func apply_performance() -> void:
 if petals==null:return
 visible=enabled;foreground.visible=enabled
 var effective: int=0 if low_power else quality
 if _texture_quality!=effective:
  _texture_quality=effective
  if not displayed_path.is_empty():
   var decoded: Dictionary=Images.decode(displayed_path,texture_edge())
   if decoded.has("image"):background.texture=ImageTexture.create_from_image(decoded.image)
  if fade_progress<1.:
   var decoded: Dictionary=Images.decode(_target_path,texture_edge())
   if decoded.has("image"):incoming.texture=ImageTexture.create_from_image(decoded.image)
 var amount: float=0. if intensity<=0. else clampf(density,0,1)
 petals.multimesh.visible_instance_count=mini(roundi(40*amount),12 if low_power else [24,32,40][clampi(quality,0,2)])
 for material: ShaderMaterial in shader_materials:material.set_shader_parameter("intensity",intensity)
 for branch: TextureRect in branches:branch.visible=show_branches and intensity>0.
 if not foreground_path.is_empty():branches[1].visible=false
 shadow.material.set_shader_parameter("opacity",shadow_opacity);shadow.material.set_shader_parameter("softness",shadow_softness)
 weather.quality=quality;weather.low_power=low_power;weather.apply();_update_processing();resize()

func _update_processing() -> void:set_process(_worker!=null or (enabled and not suspended and (fade_progress<1. or (parallax and intensity>0.))))

func _pause_shaders() -> void:
 var now: float=Time.get_ticks_msec()/1000.
 if suspended:_pause_start=now
 else:_offset+=now-_pause_start
 for material: ShaderMaterial in shader_materials:
  material.set_shader_parameter("paused_at",now-_offset if suspended else -1.);material.set_shader_parameter("time_offset",_offset)
 if weather!=null:weather.pause_at(now-_offset if suspended else -1.,_offset)
 _update_processing()

func _process(delta: float) -> void:
 if _worker!=null and not _worker.is_alive():
  var decoded: Dictionary=_worker.wait_to_finish();_worker=null
  var slot: String=_loading_slot;_loading_slot=""
  if decoded.has("error"):message=decoded.error
  elif requested_slot==slot:
   if _loading_edge!=texture_edge() or _loading_path!=str(slot_paths.get(slot,"")):select_slot(slot,fade_duration)
   else:_begin_fade(slot,_loading_path,decoded.image)
  if _worker==null and fade_progress>=1. and not _queued_slot.is_empty():
   var queued: String=_queued_slot;_queued_slot="";select_slot(queued,fade_duration)
  scenery_changed.emit()
 if suspended or not enabled:_update_processing();return
 if fade_progress<1.:
  fade_progress=minf(1.,fade_progress+maxf(0.,delta)/fade_duration);incoming.modulate.a=smoothstep(0.,1.,fade_progress)
  if fade_progress>=1.:
   background.texture=incoming.texture;incoming.texture=null;incoming.visible=false;displayed_slot=_target_slot;displayed_path=_target_path;_fade_from=displayed_slot;_target_slot=""
   message="Displaying local %s image."%displayed_slot;scenery_changed.emit()
   if not _queued_slot.is_empty():
    var queued: String=_queued_slot;_queued_slot="";select_slot(queued,fade_duration)
 _clock+=delta
 if parallax and intensity>0. and _clock>=.1:
  _clock=0.
  var t: float=Time.get_ticks_msec()/1000.-_offset
  for picture: TextureRect in [background,incoming]:picture.position=Vector2(-12.+sin(t*.08)*5.*intensity,-12.+sin(t*.06)*3.*intensity)
 _update_processing()

func _dimensions(data: PackedByteArray,kind: String) -> Vector2i:return Images._dimensions(data,kind)
