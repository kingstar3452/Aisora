class_name AisoraGroundMotion
extends RefCounted
## Opt-in short steps on a user-calibrated clear rectangle. Analytic two-bone leg IK.
const ACTIONS: Array[String]=["step_forward","step_back","pace","turn_left","turn_right"]
const WALK_ACTIONS: Array[String]=["walk_forward","walk_backward","walk_left","walk_right"]
const SUPPORTED_ACTIONS: Array[String]=["step_forward","step_back","pace","turn_left","turn_right","walk_forward","walk_backward","walk_left","walk_right"]
var _desired_left: Array[Quaternion]=[Quaternion.IDENTITY,Quaternion.IDENTITY,Quaternion.IDENTITY]
var _desired_right: Array[Quaternion]=[Quaternion.IDENTITY,Quaternion.IDENTITY,Quaternion.IDENTITY]
var turn_degrees: float=25.
var _walking: bool=false
var calibrated: bool=false
var width: float=.8
var depth: float=.9
var stride: float=.16
var active: bool=false
var paused: bool=false
var action: String=""
var origin: Vector3=Vector3.ZERO
var root_offset: Vector3=Vector3.ZERO
var heading: float=0.
var blend: float=0.
var phase: float=0.
var message: String="Calibrate a clear ground region for the current image before enabling steps."
var foot_points: Array[Vector3]=[]
var foot_angles: Array[float]=[0.,0.]
var _rest_feet: Array[Vector3]=[]
var _rest_bases: Array[Quaternion]=[]
var _leg_indices: Array[PackedInt32Array]=[]
var _leg_directions: Array[Array]=[]
var _lengths: Array[Vector2]=[]
var _queue: Array[Dictionary]=[]
var _step: Dictionary={}
var _step_start: Vector3
var _root_start: Vector3
var _heading_start: float=0.
var _returning: bool=false
var _time: float=0.
var measure_contacts: bool=false
var _step_start_angle: float=0.
var max_stance_error: float=0.

func setup(c: Node) -> void:
 for side: String in ["Left","Right"]:
  var upper: int=c.bone_indices[side+"UpperLeg"];var lower: int=c.bone_indices[side+"LowerLeg"];var foot: int=c.bone_indices[side+"Foot"]
  _leg_indices.append(PackedInt32Array([upper,lower,foot]))
  var a: Transform3D=c.skeleton.get_bone_global_rest(upper);var b: Transform3D=c.skeleton.get_bone_global_rest(lower);var f: Transform3D=c.skeleton.get_bone_global_rest(foot)
  _rest_feet.append(f.origin);_rest_bases.append(f.basis.get_rotation_quaternion());_lengths.append(Vector2(a.origin.distance_to(b.origin),b.origin.distance_to(f.origin)))
  _leg_directions.append([(b.origin-a.origin).normalized(),(f.origin-b.origin).normalized(),a.basis.get_rotation_quaternion(),b.basis.get_rotation_quaternion()])
 reset_origin(c)

func reset_origin(c: Node) -> void:
 if active:return
 origin=c.position;root_offset=Vector3.ZERO;heading=0.;c.rotation.y=0.
 foot_points.clear();foot_angles=[0.,0.]
 for point: Vector3 in _rest_feet:foot_points.append(c.to_global(point))

func play(name_value: String,c: Node) -> bool:
 if name_value not in SUPPORTED_ACTIONS or not calibrated or active or (c.get("body")!=null and c.body.active) or c.motion.conversation_active or c.state!=0 or c.motion.sleep_amount>.01:
  message="Steps need calibrated clear ground, idle state and no active/pending Voice.";return false
 _walking=name_value in WALK_ACTIONS
 reset_origin(c);_queue.clear();_step.clear();_returning=false;phase=0.;blend=0.;_time=0.;max_stance_error=0.
 var distance: float=minf(stride,maxf(.05,depth*.5-.19))
 if width<.6 or depth<distance*2.+.38:message="Ground region too small for safe steps.";return false
 var rest_left: Vector3=_rest_feet[0]*c.scale.x;var rest_right: Vector3=_rest_feet[1]*c.scale.x
 if _walking:
  var direction: Vector3=Vector3(0,0,1)
  if name_value=="walk_backward":direction=Vector3(0,0,-1)
  elif name_value=="walk_left":direction=Vector3(1,0,0)
  elif name_value=="walk_right":direction=Vector3(-1,0,0)
  var available: float=(depth*.5-.20*c.scale.x) if direction.z!=0 else (width*.5-.29*c.scale.x)
  var step_length: float=minf(.18*c.scale.x,available/3.)
  if step_length<.065*c.scale.x:message="Enlarge the calibrated area for a three-step walk.";return false
  var lead: int=1 if direction.x<0. else 0
  var feet: Array[Vector3]=[rest_left,rest_right]
  for cycle in range(1,4):
   _add(lead,feet[lead]+direction*step_length*cycle,0.);_add(1-lead,feet[1-lead]+direction*step_length*cycle,0.)
  for cycle in [2,1,0]:
   _add(1-lead,feet[1-lead]+direction*step_length*cycle,0.);_add(lead,feet[lead]+direction*step_length*cycle,0.)
 elif name_value in ["turn_left","turn_right"]:
  var angle: float=deg_to_rad(clampf(turn_degrees,15.,90.))*(1. if name_value=="turn_left" else -1.)
  var turn: Basis=Basis(Vector3.UP,angle)
  _add(0,turn*rest_left,angle);_add(1,turn*rest_right,angle)
 else:
  var sign_value: float=-1. if name_value=="step_back" else 1.
  _add(0,rest_left+Vector3(0,0,distance*sign_value),0.);_add(1,rest_right+Vector3(0,0,distance*sign_value),0.)
  if name_value=="pace":
   var further: float=minf(distance*1.5,depth*.5-.19)
   _add(0,rest_left+Vector3(0,0,further*sign_value),0.);_add(1,rest_right+Vector3(0,0,further*sign_value),0.)
 if not _walking:_add(0,rest_left,0.);_add(1,rest_right,0.)
 var planned_feet: Array[Vector3]=[rest_left,rest_right]
 var home_midpoint: Vector3=(rest_left+rest_right)*.5
 for step: Dictionary in _queue:
  planned_feet[step.side]=step.point
  var middle: Vector3=(planned_feet[0]+planned_feet[1])*.5-home_midpoint
  if absf(middle.x)+.26*c.scale.x>width*.5 or absf(middle.z)+.18*c.scale.x>depth*.5:
   message="Ground region needs additional body clearance for these steps.";_queue.clear();return false
  var point: Vector3=step.point
  if absf(point.x)>width*.5 or absf(point.z)>depth*.5:message="Planned foot placement exceeds the calibrated rectangle.";_queue.clear();return false
 action=name_value;active=true;c.motion.locomotion_active=true;c.motion.cancelling=true;c.motion.queued_gesture="";message="Short articulated steps · "+name_value.replace("_"," ");return true

func _add(side: int,point: Vector3,angle: float) -> void:_queue.append({"side":side,"point":point,"angle":angle})

func _next_step(c: Node) -> void:
 if _queue.is_empty():_returning=true;return
 _step=_queue.pop_front();phase=0.;_step_start=foot_points[_step.side];_step_start_angle=foot_angles[_step.side];_root_start=root_offset;_heading_start=heading

func tick(c: Node,delta: float) -> void:
 if not active:return
 var dt: float=clampf(delta,0.,.1);_time+=dt
 c.motion.locomotion_active=true
 var stop_for_voice: bool=paused or c.motion.conversation_active or c.state!=0
 if _returning:
  blend=move_toward(blend,0.,dt/.7)
  if blend<=0.:
   active=false;c.motion.locomotion_active=false;c.position=origin;c.rotation.y=0.;root_offset=Vector3.ZERO;heading=0.
   for ids: PackedInt32Array in _leg_indices:
    for index: int in ids:
     var bone: String=c.pose_safety.names[index];c._world_pose(bone,c.motion.poses.get(bone,Vector3.ZERO))
   message="Returned to the original ground anchor.";return
 elif blend<1.:
  blend=move_toward(blend,1.,dt/.7)
 elif _step.is_empty():
  if not stop_for_voice:_next_step(c)
 elif phase<1.:
  phase=minf(1.,phase+dt/(.66 if _walking else .9))
  var weight: float=smoothstep(0.,1.,phase)
  var side: int=_step.side
  var goal: Vector3=origin+Vector3(_step.point)
  foot_points[side]=_step_start.lerp(goal,weight)+Vector3(0,sin(phase*PI)*.045,0)
  foot_angles[side]=lerp_angle(_step_start_angle,float(_step.angle),weight)
  var other: int=1-side
  var midpoint: Vector3=(goal+foot_points[other])*.5-origin
  var home_midpoint: Vector3=(_rest_feet[0]+_rest_feet[1])*.5*c.scale.x
  var target_root: Vector3=Vector3(midpoint.x-home_midpoint.x,0,midpoint.z-home_midpoint.z)
  root_offset=_root_start.lerp(target_root,weight)
  heading=lerpf(_heading_start,(float(_step.angle)+foot_angles[other])*.5,weight)
  if phase>=1.:
   foot_points[side]=goal;foot_angles[side]=_step.angle;_step.clear()
 # Stop safely with both feet planted. Return steps wait until the conversation ends.
 c.position=origin+root_offset+Vector3(0,(-.012+(sin(phase*PI)*.007 if _walking and not _step.is_empty() else 0.))*blend,0);c.rotation.y=heading
 var hips_pose: Transform3D=c.pose_safety.joint_pose("Hips",c.motion.poses,c.motion.hips_offset)
 for side in 2:_solve_leg(c,side,foot_points[side],foot_angles[side],blend,hips_pose)
 # A small world-axis swing after the baseline pose, using cached FK rather than native skeleton queries.
 if not stop_for_voice and not _step.is_empty():
  var swing: float=sin(phase*PI)*.09*blend*(1. if int(_step.side)==0 else -1.)
  if Vector3(_step.point).z<_step_start.z-origin.z:swing=-swing
  for side: String in ["Left","Right"]:
   var index: int=c.bone_indices[side+"UpperArm"]
   var parent_q: Quaternion=c.pose_safety.joint_pose(side+"Shoulder",c.motion.poses,c.motion.hips_offset).basis.get_rotation_quaternion()
   var delta_q: Quaternion=Quaternion(Vector3.RIGHT,swing*(1. if side=="Left" else -1.))
   c._write_rotation(index,(parent_q.inverse()*delta_q*parent_q*Quaternion(c._last_rotations[index])).normalized())

func _solve_leg(c: Node,side: int,world_target: Vector3,foot_yaw: float,weight: float,parent_pose: Transform3D,foot_pitch: float=0.) -> void:
 var ids: PackedInt32Array=_leg_indices[side]
 var hip: Vector3=parent_pose*Vector3(c.rest_positions[ids[0]])
 var target: Vector3=c.skeleton.to_local(world_target)
 var ray: Vector3=target-hip
 var a: float=_lengths[side].x;var b: float=_lengths[side].y
 var distance: float=clampf(ray.length(),absf(a-b)+.005,a+b-.001)
 var direction: Vector3=ray.normalized()
 var pole: Vector3=Vector3.BACK-direction*Vector3.BACK.dot(direction)
 if pole.length_squared()<.0001:pole=Vector3.RIGHT
 pole=pole.normalized()
 var along: float=(a*a-b*b+distance*distance)/(2.*distance)
 var knee: Vector3=hip+direction*along+pole*sqrt(maxf(0.,a*a-along*along))
 var upper_q: Quaternion=Quaternion(Vector3(_leg_directions[side][0]),(knee-hip).normalized())*Quaternion(_leg_directions[side][2])
 var lower_q: Quaternion=Quaternion(Vector3(_leg_directions[side][1]),(target-knee).normalized())*Quaternion(_leg_directions[side][3])
 var foot_q: Quaternion=Quaternion(Vector3.RIGHT,foot_pitch)*Quaternion(Vector3.UP,foot_yaw-heading)*_rest_bases[side]
 var desired: Array[Quaternion]=_desired_left if side==0 else _desired_right
 desired[0]=parent_pose.basis.get_rotation_quaternion().inverse()*upper_q;desired[1]=upper_q.inverse()*lower_q;desired[2]=lower_q.inverse()*foot_q
 for i in 3:
  var bone: String=c.pose_safety.names[ids[i]]
  var offset: Vector3=c.motion.poses.get(bone,Vector3.ZERO)
  var world_q: Quaternion=Quaternion(Vector3.BACK,offset.z)*Quaternion(Vector3.RIGHT,offset.x)*Quaternion(Vector3.UP,offset.y)
  var baseline: Quaternion=c.parent_inverse_quaternions[ids[i]]*world_q*c.parent_quaternions[ids[i]]*c.rest_rotations[ids[i]]
  c._write_rotation(ids[i],baseline.slerp(desired[i].normalized(),weight).normalized())
 if measure_contacts and weight>=.999 and (_step.is_empty() or int(_step.side)!=side):
  var actual: Vector3=c.skeleton.to_global(c.skeleton.get_bone_global_pose(ids[2]).origin)
  max_stance_error=maxf(max_stance_error,actual.distance_to(world_target))

func shadow_position() -> Vector3:return origin+root_offset
