extends RefCounted
## Developer-only CPU skinning probe. Never runs in the application.
var bounds: Dictionary={}
var details: Dictionary={}
var meshes: Array[Dictionary]=[]
func _init(c: Node) -> void:
 for mesh: MeshInstance3D in c.model.find_children("*","MeshInstance3D",true,false):
  var bindings: Array[Dictionary]=[]
  for j in mesh.skin.get_bind_count():
   var bone: int=mesh.skin.get_bind_bone(j)
   if bone<0:bone=c.bone_indices[str(mesh.skin.get_bind_name(j))]
   bindings.append({"bone":bone,"inverse":mesh.skin.get_bind_pose(j)})
  var surfaces: Array[Array]=[]
  for surface in mesh.mesh.get_surface_count():surfaces.append(mesh.mesh.surface_get_arrays(surface))
  meshes.append({"name":str(mesh.name),"bindings":bindings,"surfaces":surfaces})
func floor_minima(c: Node) -> Dictionary:
 var result: Dictionary={}
 for mesh: Dictionary in meshes:
  var palette: Array[Transform3D]=[]
  for binding: Dictionary in mesh.bindings:palette.append(c.skeleton.get_bone_global_pose(binding.bone)*Transform3D(binding.inverse))
  var lowest: float=INF
  var min_point: Vector3=Vector3(INF,INF,INF);var max_point: Vector3=-min_point
  for surface: Array in mesh.surfaces:
   var vertices: PackedVector3Array=surface[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=surface[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=surface[Mesh.ARRAY_WEIGHTS]
   var stride: int=bones.size()/vertices.size()
   for i in vertices.size():
    var point: Vector3=Vector3.ZERO
    for j in stride:
     var w: float=weights[i*stride+j]
     if w>0.:point+=(palette[bones[i*stride+j]]*vertices[i])*w
    point=c.skeleton.to_global(point);min_point=min_point.min(point);max_point=max_point.max(point)
    var height: float=point.y
    if height<lowest:
     lowest=height
     var most: int=0
     for k in stride:
      if weights[i*stride+k]>weights[i*stride+most]:most=k
     details[mesh.name]=c.skeleton.get_bone_name(mesh.bindings[bones[i*stride+most]].bone)
  result[mesh.name]=lowest;bounds[mesh.name]=AABB(min_point,max_point-min_point)
 return result
