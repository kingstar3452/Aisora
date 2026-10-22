class_name AisoraFullBody
extends RefCounted
## Calibrated virtual seat/floor. Hips, spine, limbs, skirt and tail articulate independently.
const Limb=preload("res://scripts/limb_ik.gd")
const ACTIONS: Array[String]=["sit","lie_down","sleep","stand","wake"]
var enabled: bool=false
var active: bool=false
var seat_height: float=.48
var seat: float=0.
var recline: float=0.
var sleep_amount: float=0.
var desired: String="stand"
var origin: Vector3
var message: String="Full-body rest is opt-in and requires calibrated clear floor/seat space."
var hold_seconds: float=-1.
var _shift_wait: float=30.
var _shift: float=0.
var _shift_target: float=0.
var _time: float=0.
var _cleanup: bool=false
var _wake_stretch: bool=false
var position_writes: int=0
var _inverse_legs: Array[Transform3D]=[Transform3D.IDENTITY,Transform3D.IDENTITY]
var _inverse_quaternions: Array[Quaternion]=[Quaternion.IDENTITY,Quaternion.IDENTITY]
var _arms: Array[AisoraLimbIK]=[]
var _legs: Array[AisoraLimbIK]=[]
var _cloth: Array[Dictionary]=[]
var _hip_height: float
var _feet: Array[Vector3]=[]
func setup(c: Node) -> void:
 _hip_height=c.skeleton.get_bone_global_rest(c.bone_indices.Hips).origin.y
 for side: String in ["Left","Right"]:_arms.append(Limb.new(c,side,false));_legs.append(Limb.new(c,side,true))
 for i in c.skeleton.get_bone_count():
  var name: String=c.skeleton.get_bone_name(i)
  if "SkirtFront0_" in name or "SkirtBack0_" in name or "SkirtFront1_" in name or "SkirtBack1_" in name:
   var rest: Transform3D=c.skeleton.get_bone_global_rest(i)
   _cloth.append({"index":i,"side":0 if "_L_" in name else 1,"root":"0_" in name,"front":"Front" in name,"offset":rest.origin-Vector3(0,_hip_height,c.skeleton.get_bone_global_rest(c.bone_indices.Hips).origin.z),"rotation":rest.basis.get_rotation_quaternion(),"parent_rotation":c.skeleton.get_bone_global_rest(c.skeleton.get_bone_parent(i)).basis.get_rotation_quaternion(),"position":c.rest_positions[i],"last_position":c.rest_positions[i],"angle":INF,"cached_rotation":c.rest_rotations[i]})
func play(name: String,c: Node) -> bool:
 if name not in ACTIONS:return false
 if name in ["wake","stand"]:
  if not active:return true
  desired="stand";_wake_stretch=true;return true
 if not enabled or not c.ground.calibrated or c.ground.active or c.motion.conversation_active or c.state!=0 or c.motion.sleep_amount>.01:
  message="End Voice, return to idle, enable full-body rest and calibrate this image first.";return false
 if c.ground.width<(1.8 if name in ["lie_down","sleep"] else 1.)*c.scale.x or c.ground.depth<(2.4 if name in ["lie_down","sleep"] else 2.)*c.scale.x:
  message="Rest needs clear space 1.0 × 2.0 m seated / 1.8 × 2.4 m lying, scaled with Aisora.";return false
 seat_height=clampf(seat_height,.48,.60)
 if not active:
  origin=c.position;_feet.clear()
  for point: Vector3 in c.ground._rest_feet:_feet.append(c.to_global(point))
 hold_seconds=-1.;desired=name;active=true;_cleanup=true;c.motion.locomotion_active=true;c.motion.cancelling=true;c.motion.queued_gesture=""
 message="Full-body "+name.replace("_"," ")+" · calibrated virtual contacts";return true
func advance(c: Node,delta: float) -> void:
 if not active:return
 var dt: float=clampf(delta,0.,.1);_time+=dt
 if c.motion.conversation_active:desired="stand";_wake_stretch=false
 if hold_seconds>=0. and seat>=1. and (desired=="sit" or recline>=1.):
  hold_seconds-=dt
  if hold_seconds<=0.:desired="stand";hold_seconds=-1.;_wake_stretch=true
 sleep_amount=move_toward(sleep_amount,1. if desired=="sleep" and recline>=.999 else 0.,dt/(2.4 if desired=="sleep" else .6))
 if desired=="stand":
  recline=move_toward(recline,0.,dt/4.)
  if recline<=0.:seat=move_toward(seat,0.,dt/3.)
 else:
  seat=move_toward(seat,1.,dt/3.)
  if seat>=1.:recline=move_toward(recline,1. if desired in ["lie_down","sleep"] else 0.,dt/4.)
 if desired=="sleep" and sleep_amount>.95:
  _shift_wait-=dt
  if _shift_wait<=0.:_shift_target=c.rng.randf_range(-1.,1.);_shift_wait=c.rng.randf_range(28.,55.)
 else:_shift_target=0.
 _shift=lerpf(_shift,_shift_target,1.-exp(-dt*.25))
 c.motion.external_sleep=sleep_amount;c.motion.locomotion_active=true
 var a: float=smoothstep(0.,1.,seat);var b: float=smoothstep(0.,1.,recline)
 var lowered: float=lerpf(_hip_height-(seat_height+.12),_hip_height-.222,smoothstep(.52,1.,b))*a
 c.position=origin+Vector3(0,-lowered+.008*sin(PI*b),lerpf(-.30,-.15,b)*a)*c.scale.x
 if seat<=0. and recline<=0. and desired=="stand":
  active=false;c.position=origin;c.motion.external_sleep=0.;c.motion.locomotion_active=false
  if _wake_stretch and not c.motion.conversation_active:c.motion.start_gesture("stretch")
  message="Returned to standing at the original anchor."
func compose(c: Node,poses: Dictionary) -> void:
 if not active:return
 var a: float=smoothstep(0.,1.,seat);var b: float=smoothstep(0.,1.,recline)
 for side: String in ["Left","Right"]:
  for part: String in ["UpperLeg","LowerLeg","Foot"]:poses[side+part]=Vector3.ZERO
 poses.Hips=Vector3(-1.48*b,0,0)
 poses.Spine=Vector3(.035*a*(1.-b)+sin(c.motion.breath_phase)*.009,0,0)
 poses.Chest=Vector3(sin(c.motion.breath_phase)*.008,0,0)
 poses.Neck=Vector3(.08*b,0,0)
 poses.Head=Vector3(poses.get("Head",Vector3.ZERO))*.45+Vector3(.03*b,0,(sin(_time*.17)*.015+_shift*.025)*b*sleep_amount)
 poses.J_Opt_C_FoxTail1_01=Vector3(-.35,1.4,0)*smoothstep(0.,.45,recline)
 for name: String in ["J_Sec_Hair1_01","J_Sec_Hair1_02"]:poses[name]=Vector3(-.3*b,0,0)
func apply(c: Node) -> void:
 if not active:
  if _cleanup:
   for item: Dictionary in _cloth:
    if not Vector3(item.last_position).is_equal_approx(item.position):c.skeleton.set_bone_pose_position(item.index,item.position);item.last_position=item.position;position_writes+=1
    c._write_rotation(item.index,c.rest_rotations[item.index])
   _cleanup=false
  return
 var a: float=smoothstep(0.,1.,seat);var b: float=smoothstep(0.,1.,recline)
 c.pose_safety.prepare_pose(c.motion.poses,c.motion.hips_offset)
 var hips: Transform3D=c.pose_safety.prepared_joint("Hips")
 for side in 2:
  var mirror: float=1. if side==0 else -1.
  var floor_foot: Vector3=origin+Vector3(mirror*.10,.10,.52+_shift*.015*mirror)*c.scale.x
  var target: Vector3=_feet[side].lerp(floor_foot,b)+Vector3(0,.020*sin(PI*b)*c.scale.x,0)
  var foot_q: Quaternion=Quaternion(Vector3.RIGHT,-1.1*b)*_legs[side].rest_quaternions[2]
  _legs[side].solve(c,target,hips,foot_q,Vector3.BACK,1.)
  var hand: Vector3=origin+Vector3(mirror*lerpf(.16,.28,b),lerpf(seat_height+.20,.10,b),lerpf(-.08,-.35+_shift*.01*mirror,b))*c.scale.x
  var parent: Transform3D=c.pose_safety.prepared_joint(_arms[side].parent_name)
  var hand_q: Quaternion=Quaternion(Vector3.UP,-PI*.5*mirror)*_arms[side].rest_quaternions[2]
  _arms[side].solve(c,hand,parent,hand_q,Vector3(mirror,0,0),a)
 var hq: Quaternion=hips.basis.get_rotation_quaternion()
 for side in 2:
  # Limb IK constructs orthonormal quaternion bases, so transpose inversion
  # is exact here; no affine scale/shear inverse is needed.
  _inverse_legs[side]=_legs[side].transforms[0].inverse();_inverse_quaternions[side]=_legs[side].transforms[0].basis.get_rotation_quaternion().inverse()
 for item: Dictionary in _cloth:
  if item.root:
   var position_value: Vector3=Vector3(item.position).lerp(_inverse_legs[item.side]*(hips*Vector3(item.offset)),a)
   if not position_value.is_equal_approx(item.last_position):c.skeleton.set_bone_pose_position(item.index,position_value);item.last_position=position_value;position_writes+=1
   var desired_q: Quaternion=_inverse_quaternions[item.side]*hq*Quaternion(item.rotation)
   c._write_rotation(item.index,Quaternion(c.rest_rotations[item.index]).slerp(desired_q.normalized(),a).normalized())
  else:
   var angle: float=lerpf(-1.15,-.1,b) if item.front else -.6*b
   # Root has been anchored to the pelvis, so this is a local rest-axis correction.
   if not is_equal_approx(angle,item.angle):
    item.cached_rotation=(Quaternion(item.parent_rotation).inverse()*Quaternion(Vector3.RIGHT,angle)*Quaternion(item.rotation)).normalized();item.angle=angle
   c._write_rotation(item.index,Quaternion(c.rest_rotations[item.index]).slerp(item.cached_rotation,a).normalized())
