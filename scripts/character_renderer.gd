class_name AisoraCharacterRenderer
extends Node
## Optional 3D-only resolution reduction. Shares the world/VRM; never a second character.
var scale_factor: float=1.
var viewport: SubViewport
var camera: Camera3D
var layer: CanvasLayer
var picture: TextureRect
var source_camera: Camera3D
var active: bool=false
var minimized: bool=false
var max_edge: int=1280
var _source_mask: int=1

func setup(source: Camera3D) -> void:
 source_camera=source;_source_mask=source.cull_mask
 get_viewport().size_changed.connect(resize)

func configure(value: float,illustrated: bool,hidden: bool=false) -> void:
 value=clampf(value,.5,1.)
 var needed: bool=illustrated and value<.99
 minimized=hidden
 if needed and viewport==null:_build()
 scale_factor=value
 if active!=needed:
  active=needed
  if layer!=null:layer.visible=active
 source_camera.cull_mask=0 if active or minimized else _source_mask
 if viewport!=null:
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active and not minimized else SubViewport.UPDATE_DISABLED
 if active:sync_camera();resize()

func _build() -> void:
 viewport=SubViewport.new();viewport.name="Reduced3D";viewport.transparent_bg=true;viewport.world_3d=get_viewport().world_3d;viewport.handle_input_locally=false;viewport.gui_disable_input=true;viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS;add_child(viewport)
 camera=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.cull_mask=_source_mask
 var environment: Environment=Environment.new();environment.background_mode=Environment.BG_CLEAR_COLOR;camera.environment=environment
 layer=CanvasLayer.new();layer.layer=0;add_child(layer)
 picture=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_SCALE;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.texture=viewport.get_texture();layer.add_child(picture)

func resize() -> void:
 if viewport==null or not active:return
 var extent: Vector2=get_viewport().get_visible_rect().size
 var native_size: Vector2=get_viewport().get_texture().get_size()
 var amount: float=minf(scale_factor,float(max_edge)/maxf(native_size.x,native_size.y))
 var desired: Vector2i=Vector2i(maxi(1,roundi(native_size.x*amount)),maxi(1,roundi(native_size.y*amount)))
 if viewport.size!=desired:viewport.size=desired
 picture.position=Vector2.ZERO;picture.size=extent
 viewport.msaa_3d=get_viewport().msaa_3d

func sync_camera() -> void:
 if not active:return
 camera.global_transform=source_camera.global_transform;camera.fov=source_camera.fov;camera.near=source_camera.near;camera.far=source_camera.far;camera.keep_aspect=source_camera.keep_aspect
 # The root canvas stays native resolution; only the shared 3D world is reduced.
 var source_environment: Environment=get_viewport().world_3d.environment
 if source_environment!=null:
  camera.environment.ambient_light_source=source_environment.ambient_light_source;camera.environment.ambient_light_color=source_environment.ambient_light_color;camera.environment.ambient_light_energy=source_environment.ambient_light_energy

func _exit_tree() -> void:
 if is_instance_valid(source_camera):source_camera.cull_mask=_source_mask
