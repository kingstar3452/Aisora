class_name AisoraPoseSafety
extends RefCounted
## Small calibrated body proxies, not a mesh/cloth collision solver. Pure cached FK.
const ARM_PARTS: Array[String]=["UpperArm","LowerArm","Hand"]
var indices: Dictionary
var parents: PackedInt32Array=PackedInt32Array()
var names: PackedStringArray=PackedStringArray()
var positions: Array[Vector3]=[]
var rotations: Array[Quaternion]=[]
var axes: Array[Quaternion]=[]
var inverse_axes: Array[Quaternion]=[]
var cache: Dictionary={}
var last_safe: Dictionary={}
var limited: Dictionary={}
var blocked_samples: int=0
var last_hits: int=0
var _poses: Dictionary
var _hips: Vector3
var _chest: Vector3
var _head: Vector3
var _skirt: Vector3

func _init(character: Node) -> void:
 indices=character.bone_indices
 for i in character.skeleton.get_bone_count():
  names.append(character.skeleton.get_bone_name(i));parents.append(character.skeleton.get_bone_parent(i));positions.append(character.rest_positions[i]);rotations.append(character.rest_rotations[i]);axes.append(character.parent_quaternions[i]);inverse_axes.append(character.parent_inverse_quaternions[i])

func _global(index: int) -> Transform3D:
 if cache.has(index):return cache[index]
 var offset: Vector3=_poses.get(names[index],Vector3.ZERO)
 var q: Quaternion=rotations[index]
 if offset!=Vector3.ZERO:
  var world: Quaternion=Quaternion(Vector3.BACK,offset.z)*Quaternion(Vector3.RIGHT,offset.x)*Quaternion(Vector3.UP,offset.y)
  q=inverse_axes[index]*world*axes[index]*q
 var position_value: Vector3=positions[index]+(_hips if names[index]=="Hips" else Vector3.ZERO)
 var value: Transform3D=Transform3D(Basis(q),position_value)
 if parents[index]>=0:value=_global(parents[index])*value
 cache[index]=value;return value

func _inside(point: Vector3,center: Vector3,radii: Vector3) -> bool:
 return ((point-center)/radii).length_squared()<1.

func _hit(point: Vector3) -> bool:
 return _inside(point,_chest,Vector3(.138,.21,.175)) or _inside(point,_head,Vector3(.108,.145,.105)) or _inside(point,_skirt,Vector3(.255,.145,.20))

func hits(side: String) -> int:
 var elbow: Vector3=_global(indices[side+"LowerArm"]).origin
 var hand: Vector3=_global(indices[side+"Hand"]).origin
 var count: int=0
 for fraction: float in [.25,.5,.75,1.]:
  if _hit(elbow.lerp(hand,fraction)):count+=1
 for finger: String in ["Index","Middle","Ring","Little"]:
  var bone: String=side+finger+"Distal"
  if indices.has(bone) and _hit(_global(indices[bone]).origin):count+=1
 return count

func evaluate(poses_value: Dictionary,hips_value: Vector3) -> int:
 _poses=poses_value;_hips=hips_value;cache.clear()
 _chest=_global(indices.Chest).origin+Vector3(0,.015,.005)
 _head=_global(indices.Head).origin+Vector3(0,.075,0)
 _skirt=_global(indices.Hips).origin+Vector3(0,-.025,0)
 return hits("Left")+hits("Right")

func constrain(poses_value: Dictionary,hips_value: Vector3,delta: float,active: bool) -> void:
 # No FK work during normal idle. Neutral arms are authored outside the skirt.
 if not active:
  last_safe.clear();limited.clear();return
 _poses=poses_value;_hips=hips_value;cache.clear();last_hits=0
 _chest=_global(indices.Chest).origin+Vector3(0,.015,.005)
 _head=_global(indices.Head).origin+Vector3(0,.075,0)
 _skirt=_global(indices.Hips).origin+Vector3(0,-.025,0)
 for side: String in ["Left","Right"]:
  for part: String in ARM_PARTS:
   var name_value: String=side+part
   var proposed: Vector3=poses_value.get(name_value,Vector3.ZERO)
   if limited.has(name_value):proposed=Vector3(limited[name_value]).move_toward(proposed,maxf(.001,delta)*3.2)
   poses_value[name_value]=proposed
  cache.clear()
  var count: int=hits(side)
  last_hits+=count
  if count>0 and last_safe.has(side):
   blocked_samples+=1
   for part: String in ARM_PARTS:poses_value[side+part]=last_safe[side][part]
  else:
   if not last_safe.has(side):last_safe[side]={}
   for part: String in ARM_PARTS:last_safe[side][part]=poses_value.get(side+part,Vector3.ZERO)
  for part: String in ARM_PARTS:limited[side+part]=poses_value.get(side+part,Vector3.ZERO)

func joint_pose(name_value: String,poses_value: Dictionary,hips_value: Vector3) -> Transform3D:
 prepare_pose(poses_value,hips_value);return prepared_joint(name_value)

func prepare_pose(poses_value: Dictionary,hips_value: Vector3) -> void:
 # One immutable pose snapshot can serve both arm parents and the pelvis.
 _poses=poses_value;_hips=hips_value;cache.clear()

func prepared_joint(name_value: String) -> Transform3D:
 return _global(indices[name_value])
