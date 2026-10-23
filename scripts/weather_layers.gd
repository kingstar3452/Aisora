class_name AisoraWeatherLayers
extends Node2D
## Transparent scenery layers; no weather API, CPU particle loop or background warping.
const MODES: Array[String] = ["clear","cloudy","light_rain","heavy_rain","windy","misty"]
var mode: String="clear"
var strength: float=0.5
var quality: int=0
var low_power: bool=false
var budget: float=1.
var rain_enabled: bool=true
var clouds_enabled: bool=true
var fog_enabled: bool=true
var night_effects: bool=false
var nighttime: bool=false
var rain: MultiMeshInstance2D
var fireflies: MultiMeshInstance2D
var clouds: ColorRect
var fog: ColorRect
var materials: Array[ShaderMaterial]=[]
var extent: Vector2=Vector2(1280,800)

func _ready() -> void:
 set_process(false)
 clouds=_band("clouds");add_child(clouds)
 fog=_band("fog");add_child(fog)
 rain=_batch(128,Vector2(1.1,17),"rain");add_child(rain)
 fireflies=_batch(12,Vector2(5,5),"fireflies");add_child(fireflies)
 apply()

func _material(name_value: String) -> ShaderMaterial:
 var value: ShaderMaterial=ShaderMaterial.new();value.shader=load("res://assets/illustrated/%s.gdshader"%name_value);materials.append(value);return value

func _band(kind: String) -> ColorRect:
 var value: ColorRect=ColorRect.new();value.mouse_filter=Control.MOUSE_FILTER_IGNORE;value.material=_material("weather_band")
 value.material.set_shader_parameter("is_fog",kind=="fog");return value

func _batch(count: int, size_value: Vector2, kind: String) -> MultiMeshInstance2D:
 var value: MultiMeshInstance2D=MultiMeshInstance2D.new();value.multimesh=MultiMesh.new();value.multimesh.transform_format=MultiMesh.TRANSFORM_2D;value.multimesh.use_custom_data=true
 var quad: QuadMesh=QuadMesh.new();quad.size=size_value;value.multimesh.mesh=quad;value.multimesh.instance_count=count
 var rng: RandomNumberGenerator=RandomNumberGenerator.new();rng.seed=50917+count
 for i in count:
  value.multimesh.set_instance_transform_2d(i,Transform2D.IDENTITY);value.multimesh.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
 value.multimesh.custom_aabb=AABB(Vector3(-4096,-4096,-1),Vector3(8192,8192,2));value.material=_material(kind);return value

func resize(size_value: Vector2) -> void:
 extent=size_value
 if rain==null:return
 clouds.size=Vector2(extent.x,extent.y*.28);clouds.position=Vector2.ZERO
 fog.size=Vector2(extent.x,extent.y*.42);fog.position=Vector2(0,extent.y*.58)
 for material: ShaderMaterial in materials:material.set_shader_parameter("viewport_size",extent)

func apply() -> void:
 if rain==null:return
 var amount: float=clampf(strength,0,1)
 var wet: bool=mode in ["light_rain","heavy_rain"] and rain_enabled
 var maximum: int=([64,96,128][clampi(quality,0,2)] if mode=="heavy_rain" else [24,36,48][clampi(quality,0,2)])
 if low_power:maximum=24 if mode=="heavy_rain" else 12
 maximum=roundi(maximum*budget)
 rain.multimesh.visible_instance_count=roundi(maximum*amount) if wet else 0
 rain.visible=wet and amount>0
 clouds.visible=clouds_enabled and mode in ["cloudy","light_rain","heavy_rain"] and amount>0 and budget>.6
 fog.visible=fog_enabled and mode=="misty" and amount>0 and budget>.6
 fireflies.multimesh.visible_instance_count=6 if low_power or quality==0 else 12
 fireflies.visible=nighttime and night_effects and mode in ["clear","windy"] and amount>0 and budget>.3
 for material: ShaderMaterial in materials:material.set_shader_parameter("strength",amount)
 resize(extent)

func pause_at(seconds: float, offset: float) -> void:
 for material: ShaderMaterial in materials:
  material.set_shader_parameter("paused_at",seconds);material.set_shader_parameter("time_offset",offset)
