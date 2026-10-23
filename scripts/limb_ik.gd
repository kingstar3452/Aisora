class_name AisoraLimbIK
extends RefCounted
## Cached actual-rig analytic two-bone solver; no iterative search or bone queries per tick.
var ids: PackedInt32Array
var parent_name: String
var root_position: Vector3
var directions: Array[Vector3]=[]
var rest_quaternions: Array[Quaternion]=[]
var _desired: Array[Quaternion]=[Quaternion.IDENTITY,Quaternion.IDENTITY,Quaternion.IDENTITY]
var lengths: Vector2
var transforms: Array[Transform3D]=[Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY]
func _init(c: Node,side: String,leg: bool) -> void:
 ids=PackedInt32Array([c.bone_indices[side+("UpperLeg" if leg else "UpperArm")],c.bone_indices[side+("LowerLeg" if leg else "LowerArm")],c.bone_indices[side+("Foot" if leg else "Hand")]])
 parent_name=c.skeleton.get_bone_name(c.skeleton.get_bone_parent(ids[0]));root_position=c.rest_positions[ids[0]]
 var a: Transform3D=c.skeleton.get_bone_global_rest(ids[0]);var b: Transform3D=c.skeleton.get_bone_global_rest(ids[1]);var e: Transform3D=c.skeleton.get_bone_global_rest(ids[2])
 lengths=Vector2(a.origin.distance_to(b.origin),b.origin.distance_to(e.origin))
 directions=[(b.origin-a.origin).normalized(),(e.origin-b.origin).normalized()]
 rest_quaternions=[a.basis.get_rotation_quaternion(),b.basis.get_rotation_quaternion(),e.basis.get_rotation_quaternion()]
func solve(c: Node,target: Vector3,parent: Transform3D,goal_q: Quaternion,pole_axis: Vector3,weight: float) -> void:
 var start: Vector3=parent*root_position;var ray: Vector3=c.skeleton.to_local(target)-start
 var direction: Vector3=ray.normalized();var distance: float=clampf(ray.length(),absf(lengths.x-lengths.y)+.002,lengths.x+lengths.y-.001)
 var pole: Vector3=pole_axis-direction*pole_axis.dot(direction)
 if pole.length_squared()<.0001:pole=Vector3.RIGHT-direction*direction.x
 pole=pole.normalized()
 var along: float=(lengths.x*lengths.x-lengths.y*lengths.y+distance*distance)/(2.*distance)
 var middle: Vector3=start+direction*along+pole*sqrt(maxf(0.,lengths.x*lengths.x-along*along))
 var end: Vector3=start+direction*distance
 var upper: Quaternion=(Quaternion(directions[0],(middle-start).normalized())*rest_quaternions[0]).normalized()
 var lower: Quaternion=(Quaternion(directions[1],(end-middle).normalized())*rest_quaternions[1]).normalized()
 _desired[0]=parent.basis.get_rotation_quaternion().inverse()*upper;_desired[1]=upper.inverse()*lower;_desired[2]=lower.inverse()*goal_q
 for i in 3:c._write_rotation(ids[i],Quaternion(c._last_rotations[ids[i]]).slerp(_desired[i].normalized(),weight).normalized())
 transforms[0]=Transform3D(Basis(upper),start);transforms[1]=Transform3D(Basis(lower),middle);transforms[2]=Transform3D(Basis(goal_q),end)
