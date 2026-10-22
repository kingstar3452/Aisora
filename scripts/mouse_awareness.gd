class_name AisoraMouseAwareness
extends RefCounted
## Window-local, 15 Hz event sampling. No desktop tracking, raycasts or screen capture.
var target: Vector2=Vector2.ZERO
var hovered: bool=false
var entered: bool=false
var _clock: float=0.
var _hold: float=0.
var _sent_hover: bool=false
var pending: bool=false
var position: Vector2=Vector2.ZERO
var _quiet: float=0.
func moved(value: Vector2) -> void:
 position=value;pending=true;_quiet=0.
func reset() -> void:
 target=Vector2.ZERO;hovered=false;_hold=0.;_sent_hover=false;pending=false;entered=false
func sample(delta: float,app: Node) -> void:
 _clock+=delta;_quiet+=delta
 if app.character.motion.conversation_active or not app.performance.focused or app.performance.minimized or app.settings_panel.visible or app.character.motion.is_resting():reset();return
 if _quiet>2.:target=Vector2.ZERO
 if _clock<1./15.:return
 var dt: float=minf(_clock,.2);_clock=0.;entered=false
 var config: AisoraAutonomy=app.autonomy
 if not config.mouse_tracking and not config.head_tracking and not config.hover_reactions:reset();return
 if pending:
  pending=false
  var c: AisoraCharacter=app.character
  var head: Vector3=c.skeleton.global_transform*c.skeleton.get_bone_global_pose(c.bone_indices.Head).origin
  var hips: Vector3=c.skeleton.global_transform*c.skeleton.get_bone_global_pose(c.bone_indices.Hips).origin
  if app.camera.is_position_behind(head):reset();return
  var center: Vector2=app.camera.unproject_position(head)
  var hip: Vector2=app.camera.unproject_position(hips)
  var height: float=maxf(40.,absf(hip.y-center.y))
  var region: Rect2=Rect2(Vector2(minf(center.x,hip.x)-height*.48,center.y-height*.28),Vector2(absf(center.x-hip.x)+height*.96,height*2.5))
  var was: bool=hovered;hovered=region.has_point(position);entered=hovered and not was
  if not hovered:_hold=0.;_sent_hover=false
  var offset: Vector2=(position-center)/Vector2(height*2.,height*1.4)
  target=Vector2(clampf(offset.x,-1.,1.),clampf(offset.y,-1.,1.))*config.sensitivity
  if position.distance_to(center)>height*3.:target=Vector2.ZERO
 if hovered:
  _hold+=dt
  if _hold>=2. and not _sent_hover:
   _sent_hover=true
   if config.hover_reactions:config.request_event("avatar_hover",app._autonomy_context())
