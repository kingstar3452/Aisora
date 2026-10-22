extends "performance_matrix.gd"
## Additional workload, separate dataset: identical mouse events reach each version.
## Old versions ignore the input; new version adds bounded gaze/hover policy work.
func tick(app: Node,item: Dictionary,index: int) -> void:
 if index%2==0:
  var c: Node=app.character
  var head: Vector3=c.skeleton.global_transform*c.skeleton.get_bone_global_pose(c.bone_indices.Head).origin
  var event: InputEventMouseMotion=InputEventMouseMotion.new()
  event.position=app.camera.unproject_position(head)+Vector2(sin(index*.02)*12.,3.)
  app.get_viewport().push_input(event)
 super.tick(app,item,index)
