class_name AisoraIllustratedPark
extends CanvasLayer
## A canvas background behind native 3D rendering: no duplicate offscreen viewport.
const MAX_TEXTURE_EDGE: int = 1920
const MAX_FILE_BYTES: int = 20*1024*1024
var background: TextureRect
var shadow: TextureRect
var foreground: CanvasLayer
var petals: MultiMeshInstance2D
var branches: Array[TextureRect] = []
var shader_materials: Array[ShaderMaterial] = []
var enabled: bool = true
var intensity: float = 0.65
var density: float = 0.45
var quality: int = 0
var low_power: bool = false
var parallax: bool = false
var character_anchor: Vector2 = Vector2(0.5,0.94)
var character_scale: float = 1.0
var background_path: String = ""
var image_storage_dir: String = "user://"
var _texture_quality: int = -1
var foreground_path: String = ""
var message: String = "Original bundled illustration. Choose your own background in Settings."
var suspended: bool = false:
 set(value):
  if suspended == value:return
  suspended=value
  _pause_shaders()
var _pause_start: float = 0.0
var _offset: float = 0.0
var _clock: float = 0.0
var _root: Control
var ambient_material: ShaderMaterial

func _ready() -> void:
 layer=-1
 _offset=Time.get_ticks_msec()/1000.0
 _root=Control.new();_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.clip_contents=true;add_child(_root)
 background=TextureRect.new();background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.add_child(background)
 background.texture=load("res://assets/illustrated/original_garden.svg")
 ambient_material=_shader("ambient");background.material=ambient_material
 shadow=TextureRect.new();shadow.texture=load("res://assets/illustrated/shadow.svg");shadow.mouse_filter=Control.MOUSE_FILTER_IGNORE;_root.add_child(shadow)
 foreground=CanvasLayer.new();foreground.layer=0;add_child(foreground)
 for i in 2:
  var branch: TextureRect=TextureRect.new();branch.texture=load("res://assets/illustrated/branch.svg");branch.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;branch.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;branch.size=Vector2(340,212);branch.flip_h=i==1;branch.mouse_filter=Control.MOUSE_FILTER_IGNORE;branch.material=_shader("breeze");foreground.add_child(branch);branches.append(branch)
 petals=MultiMeshInstance2D.new();petals.multimesh=MultiMesh.new();petals.multimesh.transform_format=MultiMesh.TRANSFORM_2D;petals.multimesh.use_custom_data=true
 var quad: QuadMesh=QuadMesh.new();quad.size=Vector2(10,15);petals.multimesh.mesh=quad;petals.multimesh.instance_count=40
 var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=4618
 for i in 40:
  petals.multimesh.set_instance_transform_2d(i,Transform2D.IDENTITY);petals.multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),0,1))
 petals.multimesh.custom_aabb=AABB(Vector3(-4096,-4096,-1),Vector3(8192,8192,2))
 petals.texture=load("res://assets/illustrated/petal.svg");petals.material=_shader("petals_2d");foreground.add_child(petals)
 get_viewport().size_changed.connect(resize)
 if not background_path.is_empty():load_local(background_path,false,false)
 if not foreground_path.is_empty():load_local(foreground_path,true,false)
 resize();apply_performance()

func _shader(name_value: String) -> ShaderMaterial:
 var material: ShaderMaterial=ShaderMaterial.new();material.shader=load("res://assets/illustrated/%s.gdshader"%name_value);material.set_shader_parameter("time_offset",_offset);shader_materials.append(material);return material

func load_local(path: String, overlay: bool=false, copy_to_user: bool=true) -> bool:
 var file: FileAccess=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>MAX_FILE_BYTES:
  message="Image unavailable or larger than 20 MiB. Existing scenery retained.";return false
 var header: PackedByteArray=file.get_buffer(file.get_length())
 file.close()
 var kind: String=path.get_extension().to_lower()
 var signature_ok: bool=(kind=="png" and header.size()>=24 and header.slice(0,8)==PackedByteArray([137,80,78,71,13,10,26,10])) or (kind in ["jpg","jpeg"] and header.size()>=3 and header[0]==255 and header[1]==216 and header[2]==255) or (kind=="webp" and header.size()>=12 and header.slice(0,4).get_string_from_ascii()=="RIFF" and header.slice(8,12).get_string_from_ascii()=="WEBP")
 if not signature_ok:message="The selected file is not a supported image. Existing scenery retained.";return false
 if not path.get_extension().to_lower() in ["png","jpg","jpeg","webp"]:
  message="Choose a PNG, JPEG or WebP image.";return false
 var dimensions: Vector2i=_dimensions(header,kind)
 if dimensions.x<=0 or dimensions.y<=0 or dimensions.x>8192 or dimensions.y>8192 or dimensions.x*dimensions.y>16000000:
  message="Use a PNG/JPEG/WebP no larger than 16 megapixels (8192 pixels per edge).";return false
 var image_value: Image=Image.new()
 var result: Error=ERR_FILE_UNRECOGNIZED
 match kind:
  "png":result=image_value.load_png_from_buffer(header)
  "jpg","jpeg":result=image_value.load_jpg_from_buffer(header)
  "webp":result=image_value.load_webp_from_buffer(header)
 if result!=OK or image_value.is_empty():message="Image could not be decoded. Existing scenery retained.";return false
 if overlay and image_value.detect_alpha()==Image.ALPHA_NONE:
  message="Foreground images need transparency (PNG or WebP).";return false
 var edge: int=maxi(image_value.get_width(),image_value.get_height())
 if edge>MAX_TEXTURE_EDGE:
  image_value.resize(maxi(1,roundi(image_value.get_width()*float(MAX_TEXTURE_EDGE)/edge)),maxi(1,roundi(image_value.get_height()*float(MAX_TEXTURE_EDGE)/edge)),Image.INTERPOLATE_LANCZOS)
 var destination: String=path
 if copy_to_user:
  DirAccess.make_dir_recursive_absolute(image_storage_dir)
  destination=image_storage_dir.path_join("aisora-foreground.png" if overlay else "aisora-background.png")
  if image_value.save_png(destination)!=OK:message="Unable to save your local image.";return false
 var texture_edge: int=512 if overlay else ([1280,1600,1920][clampi(quality,0,2)] if not low_power else 1280)
 if maxi(image_value.get_width(),image_value.get_height())>texture_edge:
  var ratio: float=float(texture_edge)/maxi(image_value.get_width(),image_value.get_height())
  image_value.resize(maxi(1,roundi(image_value.get_width()*ratio)),maxi(1,roundi(image_value.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
 _texture_quality=0 if low_power else quality
 if overlay:
  foreground_path=destination;branches[0].texture=ImageTexture.create_from_image(image_value);branches[1].visible=false
 else:
  background_path=destination;background.texture=ImageTexture.create_from_image(image_value)
 message="Local image loaded. Image files stay outside the repository."
 resize();return true

func resize() -> void:
 if background==null:return
 var extent: Vector2=get_viewport().get_visible_rect().size
 var margin: float=12.0 if parallax else 0.0
 background.position=Vector2(-margin,-margin);background.size=extent+Vector2.ONE*margin*2.0
 shadow.size=Vector2(230,48)*character_scale;shadow.position=extent*character_anchor-shadow.size*Vector2(.5,.37)
 branches[0].position=Vector2.ZERO;branches[1].position=Vector2(extent.x-340,0)
 petals.material.set_shader_parameter("viewport_size",extent)

func apply_performance() -> void:
 if petals==null:return
 visible=enabled;foreground.visible=enabled
 var effective: int=0 if low_power else quality
 if _texture_quality!=effective:
  _texture_quality=effective
  if not background_path.is_empty():load_local(background_path,false,false)
 var amount: float=0.0 if intensity<=0.0 else clampf(density,0,1)
 petals.multimesh.visible_instance_count=mini(roundi(40*amount),12 if low_power else [24,32,40][clampi(quality,0,2)])
 for material: ShaderMaterial in shader_materials:material.set_shader_parameter("intensity",intensity)
 for branch: TextureRect in branches:branch.visible=intensity>0.0
 if not foreground_path.is_empty():branches[1].visible=false
 set_process(enabled and parallax and intensity>0.0 and not suspended)
 resize()

func _pause_shaders() -> void:
 var now: float=Time.get_ticks_msec()/1000.0
 if suspended:_pause_start=now
 else:_offset+=now-_pause_start
 for material: ShaderMaterial in shader_materials:
  material.set_shader_parameter("paused_at",now-_offset if suspended else -1.0);material.set_shader_parameter("time_offset",_offset)
 set_process(enabled and parallax and intensity>0.0 and not suspended)

func _process(delta: float) -> void:
 _clock+=delta
 if _clock<0.1:return
 _clock=0.0
 var t: float=Time.get_ticks_msec()/1000.0-_offset
 background.position=Vector2(-12.0+sin(t*.08)*5.0*intensity,-12.0+sin(t*.06)*3.0*intensity)

func _dimensions(data: PackedByteArray, kind: String) -> Vector2i:
 # Read dimensions before allocating a decoded bitmap. No per-frame image work.
 if kind=="png" and data.size()>=24:
  return Vector2i(_be32(data,16),_be32(data,20))
 if kind=="webp" and data.size()>=30:
  var chunk: String=data.slice(12,16).get_string_from_ascii()
  if chunk=="VP8X":return Vector2i(1+data[24]+(data[25]<<8)+(data[26]<<16),1+data[27]+(data[28]<<8)+(data[29]<<16))
  if chunk=="VP8 ":return Vector2i((data[26]+(data[27]<<8))&16383,(data[28]+(data[29]<<8))&16383)
  if chunk=="VP8L":return Vector2i(1+data[21]+((data[22]&63)<<8),1+(data[22]>>6)+(data[23]<<2)+((data[24]&15)<<10))
 if kind in ["jpg","jpeg"]:
  var at: int=2
  while at+4<data.size():
   if data[at]!=255:at+=1;continue
   var marker: int=data[at+1];at+=2
   if marker==255:at-=1;continue
   if marker in [216,217,1] or (marker>=208 and marker<=215):continue
   var length_value: int=(data[at]<<8)+data[at+1]
   if length_value<2 or at+length_value>data.size():return Vector2i.ZERO
   if marker in [192,193,194,195,197,198,199,201,202,203,205,206,207] and length_value>=7:
    return Vector2i((data[at+5]<<8)+data[at+6],(data[at+3]<<8)+data[at+4])
   at+=length_value
 return Vector2i.ZERO

func _be32(data: PackedByteArray, at: int) -> int:
 return (data[at]<<24)+(data[at+1]<<16)+(data[at+2]<<8)+data[at+3]
